"""
Invoice lifecycle service.

Handles the full invoice workflow:
DRAFT → SENT (finalize + FIFO allocation) → PAID → VOID (reversal)
"""

from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.models.invoice import Invoice, InvoiceItem, Payment, InvoiceStatus, PaymentStatus
from app.models.customer import Customer
from app.models.product import Product
from app.models.inventory import StockMovement, MovementType
from app.services.fifo import allocate_fifo, create_batch_allocations, reverse_fifo_allocation
from app.services.tax import calculate_invoice_taxes


async def generate_invoice_number(db: AsyncSession, tenant_id: str) -> str:
    """Generate next invoice number: INV-YYYY-NNNN."""
    year = datetime.now(timezone.utc).year
    prefix = f"INV-{year}-"

    result = await db.execute(
        select(func.count(Invoice.id)).where(
            Invoice.tenant_id == tenant_id,
            Invoice.invoice_number.like(f"{prefix}%"),
        )
    )
    count = result.scalar() or 0
    return f"{prefix}{count + 1:04d}"


async def create_draft_invoice(
    db: AsyncSession,
    tenant_id: str,
    user_id: str,
    customer_id: str,
    invoice_date,
    due_date,
    items: list[dict],
    discount_type: str | None = None,
    discount_value: float = 0,
    apply_vat: bool = True,
    apply_wht: bool = False,
    notes: str | None = None,
    terms: str | None = None,
    vat_rate: float = 0.075,
    wht_rate: float = 0.05,
) -> Invoice:
    """Create a draft invoice. No stock is deducted yet."""
    invoice_number = await generate_invoice_number(db, tenant_id)

    # Build line items and calculate subtotal
    subtotal = 0.0
    invoice_items = []
    vat_exempt_total = 0.0

    for item_data in items:
        line_total = item_data["quantity"] * item_data["unit_price"]
        subtotal += line_total

        # Check VAT exemption
        vat_item_rate = vat_rate if apply_vat else 0
        if item_data.get("product_id"):
            prod_result = await db.execute(
                select(Product).where(Product.id == item_data["product_id"])
            )
            product = prod_result.scalar_one_or_none()
            if product and not product.vat_applicable:
                vat_item_rate = 0
                vat_exempt_total += line_total

        item_vat = round(line_total * vat_item_rate, 2)

        invoice_item = InvoiceItem(
            product_id=item_data.get("product_id"),
            description=item_data["description"],
            quantity=item_data["quantity"],
            unit_price=item_data["unit_price"],
            line_total=round(line_total, 2),
            vat_rate=vat_item_rate,
            vat_amount=item_vat,
        )
        invoice_items.append(invoice_item)

    # Calculate discount
    discount_amount = 0.0
    if discount_type == "PERCENT" and discount_value > 0:
        discount_amount = round(subtotal * (discount_value / 100), 2)
    elif discount_type == "FIXED" and discount_value > 0:
        discount_amount = min(discount_value, subtotal)

    # Calculate taxes
    tax_result = calculate_invoice_taxes(
        subtotal=subtotal,
        discount_amount=discount_amount,
        apply_vat=apply_vat,
        vat_rate=vat_rate,
        apply_wht=apply_wht,
        wht_rate=wht_rate,
        vat_exempt_items_total=vat_exempt_total,
    )

    invoice = Invoice(
        tenant_id=tenant_id,
        customer_id=customer_id,
        user_id=user_id,
        invoice_number=invoice_number,
        invoice_date=invoice_date,
        due_date=due_date,
        subtotal=tax_result["subtotal"],
        discount_amount=tax_result["discount_amount"],
        discount_type=discount_type,
        discount_value=discount_value,
        vat_amount=tax_result["vat_amount"],
        wht_amount=tax_result["wht_amount"],
        wht_applied=apply_wht,
        total_amount=tax_result["total_amount"],
        outstanding_amount=tax_result["total_amount"],
        status=InvoiceStatus.DRAFT,
        payment_status=PaymentStatus.UNPAID,
        notes=notes,
        terms=terms,
    )

    db.add(invoice)
    await db.flush()  # Get invoice.id

    # Attach items
    for item in invoice_items:
        item.invoice_id = invoice.id
        db.add(item)

    return invoice


async def finalize_invoice(
    db: AsyncSession,
    invoice: Invoice,
    tenant_id: str,
    user_id: str,
) -> Invoice:
    """
    Finalize a draft invoice:
    1. Apply FIFO allocation for inventory items
    2. Calculate COGS
    3. Deduct stock
    4. Update status to SENT
    """
    if invoice.status != InvoiceStatus.DRAFT:
        raise ValueError(f"Cannot finalize invoice in {invoice.status.value} status")

    # Load items
    result = await db.execute(
        select(InvoiceItem).where(InvoiceItem.invoice_id == invoice.id)
    )
    items = result.scalars().all()

    total_cost = 0.0

    for item in items:
        if not item.product_id:
            continue

        # Check if product tracks inventory
        prod_result = await db.execute(
            select(Product).where(Product.id == item.product_id)
        )
        product = prod_result.scalar_one_or_none()
        if not product or not product.track_inventory:
            continue

        # FIFO allocation
        allocation = await allocate_fifo(
            db, tenant_id, item.product_id, item.quantity
        )

        # Create allocation records
        await create_batch_allocations(db, item.id, allocation)

        # Update item cost
        item.unit_cost = allocation.weighted_avg_cost
        item.total_cost = allocation.total_cost
        item.line_profit = float(item.line_total) - allocation.total_cost
        total_cost += allocation.total_cost

        # Create stock movement
        movement = StockMovement(
            tenant_id=tenant_id,
            product_id=item.product_id,
            movement_type=MovementType.SALE,
            quantity=-item.quantity,
            unit_value=allocation.weighted_avg_cost,
            total_value=allocation.total_cost,
            reference_type="INVOICE",
            reference_id=invoice.id,
            user_id=user_id,
            notes=f"Sale: Invoice {invoice.invoice_number}",
        )
        db.add(movement)

    # Update invoice totals
    invoice.total_cost = round(total_cost, 2)
    invoice.gross_profit = round(float(invoice.total_amount) - total_cost, 2)
    invoice.status = InvoiceStatus.SENT

    # Update customer outstanding balance
    cust_result = await db.execute(
        select(Customer).where(Customer.id == invoice.customer_id)
    )
    customer = cust_result.scalar_one_or_none()
    if customer:
        customer.total_revenue = float(customer.total_revenue) + float(invoice.total_amount)
        customer.outstanding_balance = float(customer.outstanding_balance) + float(invoice.total_amount)

    return invoice


async def record_payment(
    db: AsyncSession,
    invoice: Invoice,
    amount: float,
    payment_date,
    payment_method: str,
    reference_number: str | None = None,
    notes: str | None = None,
) -> Payment:
    """Record a payment against an invoice."""
    payment = Payment(
        invoice_id=invoice.id,
        amount=amount,
        payment_date=payment_date,
        payment_method=payment_method,
        reference_number=reference_number,
        notes=notes,
    )
    db.add(payment)

    # Update invoice payment tracking
    invoice.paid_amount = float(invoice.paid_amount) + amount
    invoice.outstanding_amount = float(invoice.total_amount) - float(invoice.paid_amount)

    # Update payment status
    if invoice.outstanding_amount <= 0:
        invoice.payment_status = PaymentStatus.PAID
        if invoice.outstanding_amount < 0:
            invoice.payment_status = PaymentStatus.OVERPAID
    elif invoice.paid_amount > 0:
        invoice.payment_status = PaymentStatus.PARTIALLY_PAID

    # Update customer balances
    cust_result = await db.execute(
        select(Customer).where(Customer.id == invoice.customer_id)
    )
    customer = cust_result.scalar_one_or_none()
    if customer:
        customer.total_paid = float(customer.total_paid) + amount
        customer.outstanding_balance = float(customer.outstanding_balance) - amount

    return payment


async def void_invoice(
    db: AsyncSession,
    invoice: Invoice,
    tenant_id: str,
    user_id: str,
) -> Invoice:
    """
    Void an invoice:
    1. Reverse FIFO allocations (restore stock)
    2. Update customer balances
    3. Set status to VOID
    """
    if invoice.status == InvoiceStatus.VOID:
        raise ValueError("Invoice is already voided")

    # Reverse stock if it was finalized
    if invoice.status != InvoiceStatus.DRAFT:
        result = await db.execute(
            select(InvoiceItem).where(InvoiceItem.invoice_id == invoice.id)
        )
        items = result.scalars().all()

        for item in items:
            if item.product_id:
                await reverse_fifo_allocation(db, item.id)

                # Create reversal stock movement
                movement = StockMovement(
                    tenant_id=tenant_id,
                    product_id=item.product_id,
                    movement_type=MovementType.RETURN,
                    quantity=item.quantity,
                    unit_value=float(item.unit_cost),
                    total_value=float(item.total_cost),
                    reference_type="VOID",
                    reference_id=invoice.id,
                    user_id=user_id,
                    notes=f"Void: Invoice {invoice.invoice_number}",
                )
                db.add(movement)

        # Reverse customer balances
        cust_result = await db.execute(
            select(Customer).where(Customer.id == invoice.customer_id)
        )
        customer = cust_result.scalar_one_or_none()
        if customer:
            customer.total_revenue = float(customer.total_revenue) - float(invoice.total_amount)
            customer.outstanding_balance = (
                float(customer.outstanding_balance) - float(invoice.outstanding_amount)
            )
            customer.total_paid = float(customer.total_paid) - float(invoice.paid_amount)

    invoice.status = InvoiceStatus.VOID
    return invoice
