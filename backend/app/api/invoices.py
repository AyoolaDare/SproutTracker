from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.user import User
from app.models.invoice import Invoice, InvoiceItem, InvoiceStatus, Payment
from app.models.customer import Customer
from app.models.tax import TaxSettings
from app.middleware.auth import get_current_user
from app.schemas.invoice import (
    InvoiceCreate,
    InvoiceUpdate,
    InvoiceResponse,
    InvoiceItemResponse,
    PaymentResponse,
    RecordPaymentRequest,
)
from app.services.invoice_service import (
    create_draft_invoice,
    finalize_invoice,
    record_payment,
    void_invoice,
)
from app.services.audit import log_action
from app.services.cache import invalidate_tenant_dashboard

router = APIRouter(prefix="/api/invoices", tags=["Invoices"])


def invoice_to_response(invoice: Invoice) -> InvoiceResponse:
    customer_name = invoice.customer.name if invoice.customer else None
    items = [
        InvoiceItemResponse.model_validate(item)
        for item in (invoice.items or [])
    ]
    payments = [
        PaymentResponse.model_validate(p)
        for p in (invoice.payments or [])
    ]
    return InvoiceResponse(
        id=invoice.id,
        invoice_number=invoice.invoice_number,
        customer_id=invoice.customer_id,
        customer_name=customer_name,
        invoice_date=invoice.invoice_date,
        due_date=invoice.due_date,
        subtotal=float(invoice.subtotal),
        discount_amount=float(invoice.discount_amount),
        vat_amount=float(invoice.vat_amount),
        wht_amount=float(invoice.wht_amount),
        total_amount=float(invoice.total_amount),
        total_cost=float(invoice.total_cost),
        gross_profit=float(invoice.gross_profit),
        paid_amount=float(invoice.paid_amount),
        outstanding_amount=float(invoice.outstanding_amount),
        status=invoice.status.value,
        payment_status=invoice.payment_status.value,
        wht_applied=invoice.wht_applied,
        notes=invoice.notes,
        terms=invoice.terms,
        items=items,
        payments=payments,
        created_at=invoice.created_at,
    )


@router.get("")
async def list_invoices(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = None,
    status: str | None = None,
    payment_status: str | None = None,
    customer_id: str | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(Invoice)
        .options(selectinload(Invoice.customer), selectinload(Invoice.items), selectinload(Invoice.payments))
        .where(Invoice.tenant_id == user.tenant_id)
    )

    if search:
        query = query.where(
            or_(
                Invoice.invoice_number.ilike(f"%{search}%"),
            )
        )
    if status:
        query = query.where(Invoice.status == status)
    if payment_status:
        query = query.where(Invoice.payment_status == payment_status)
    if customer_id:
        query = query.where(Invoice.customer_id == customer_id)

    count_q = select(func.count(Invoice.id)).where(Invoice.tenant_id == user.tenant_id)
    total = (await db.execute(count_q)).scalar() or 0

    query = query.order_by(Invoice.created_at.desc())
    query = query.offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    invoices = result.scalars().unique().all()

    return {
        "success": True,
        "data": [invoice_to_response(inv) for inv in invoices],
        "pagination": {
            "page": page,
            "limit": limit,
            "total": total,
            "total_pages": (total + limit - 1) // limit,
        },
    }


@router.get("/{invoice_id}")
async def get_invoice(
    invoice_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Invoice)
        .options(selectinload(Invoice.customer), selectinload(Invoice.items), selectinload(Invoice.payments))
        .where(Invoice.id == invoice_id, Invoice.tenant_id == user.tenant_id)
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    return {"success": True, "data": invoice_to_response(invoice)}


@router.post("", status_code=201)
async def create_invoice(
    req: InvoiceCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify customer
    cust_result = await db.execute(
        select(Customer).where(
            Customer.id == req.customer_id, Customer.tenant_id == user.tenant_id
        )
    )
    if not cust_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Customer not found")

    # Get tax settings
    tax_result = await db.execute(
        select(TaxSettings).where(TaxSettings.tenant_id == user.tenant_id)
    )
    tax_settings = tax_result.scalar_one_or_none()
    vat_rate = float(tax_settings.vat_rate) if tax_settings else 0.075
    wht_rate = float(tax_settings.wht_rate_services) if tax_settings else 0.05

    items = [item.model_dump() for item in req.items]

    invoice = await create_draft_invoice(
        db=db,
        tenant_id=user.tenant_id,
        user_id=user.id,
        customer_id=req.customer_id,
        invoice_date=req.invoice_date,
        due_date=req.due_date,
        items=items,
        discount_type=req.discount_type,
        discount_value=req.discount_value,
        apply_vat=req.apply_vat,
        apply_wht=req.apply_wht,
        notes=req.notes,
        terms=req.terms,
        vat_rate=vat_rate,
        wht_rate=wht_rate,
    )

    await log_action(db, user.tenant_id, user.id, "CREATE", "Invoice", invoice.id)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)

    # Reload with relationships
    result = await db.execute(
        select(Invoice)
        .options(selectinload(Invoice.customer), selectinload(Invoice.items), selectinload(Invoice.payments))
        .where(Invoice.id == invoice.id)
    )
    invoice = result.scalar_one()
    return {"success": True, "data": invoice_to_response(invoice)}


@router.put("/{invoice_id}")
async def update_invoice(
    invoice_id: str,
    req: InvoiceUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Invoice).where(
            Invoice.id == invoice_id, Invoice.tenant_id == user.tenant_id
        )
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    if invoice.status != InvoiceStatus.DRAFT:
        raise HTTPException(status_code=400, detail="Only draft invoices can be edited")

    # For simplicity, delete and recreate if items changed
    if req.items is not None:
        # Delete old items
        old_items_result = await db.execute(
            select(InvoiceItem).where(InvoiceItem.invoice_id == invoice_id)
        )
        for old_item in old_items_result.scalars().all():
            await db.delete(old_item)

        # Get tax settings
        tax_result = await db.execute(
            select(TaxSettings).where(TaxSettings.tenant_id == user.tenant_id)
        )
        tax_settings = tax_result.scalar_one_or_none()
        vat_rate = float(tax_settings.vat_rate) if tax_settings else 0.075

        # Recreate items
        subtotal = 0
        for item_data in req.items:
            line_total = item_data.quantity * item_data.unit_price
            subtotal += line_total
            item = InvoiceItem(
                invoice_id=invoice_id,
                product_id=item_data.product_id,
                description=item_data.description,
                quantity=item_data.quantity,
                unit_price=item_data.unit_price,
                line_total=round(line_total, 2),
                vat_rate=vat_rate if (req.apply_vat or invoice.vat_amount > 0) else 0,
                vat_amount=round(line_total * vat_rate, 2) if (req.apply_vat or invoice.vat_amount > 0) else 0,
            )
            db.add(item)

        invoice.subtotal = round(subtotal, 2)

    # Update scalar fields
    simple_fields = ["customer_id", "invoice_date", "due_date", "discount_type",
                     "discount_value", "notes", "terms"]
    updates = req.model_dump(exclude_unset=True, exclude={"items", "apply_vat", "apply_wht"})
    for key, value in updates.items():
        if key in simple_fields:
            setattr(invoice, key, value)

    await log_action(db, user.tenant_id, user.id, "UPDATE", "Invoice", invoice_id)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)

    # Reload
    result = await db.execute(
        select(Invoice)
        .options(selectinload(Invoice.customer), selectinload(Invoice.items), selectinload(Invoice.payments))
        .where(Invoice.id == invoice_id)
    )
    invoice = result.scalar_one()
    return {"success": True, "data": invoice_to_response(invoice)}


@router.post("/{invoice_id}/finalize")
async def finalize(
    invoice_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Invoice).where(
            Invoice.id == invoice_id, Invoice.tenant_id == user.tenant_id
        )
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    try:
        invoice = await finalize_invoice(db, invoice, user.tenant_id, user.id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

    await log_action(db, user.tenant_id, user.id, "FINALIZE", "Invoice", invoice_id)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)

    # Reload
    result = await db.execute(
        select(Invoice)
        .options(selectinload(Invoice.customer), selectinload(Invoice.items), selectinload(Invoice.payments))
        .where(Invoice.id == invoice_id)
    )
    invoice = result.scalar_one()
    return {"success": True, "data": invoice_to_response(invoice)}


@router.post("/{invoice_id}/void")
async def void(
    invoice_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Invoice).where(
            Invoice.id == invoice_id, Invoice.tenant_id == user.tenant_id
        )
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")

    try:
        invoice = await void_invoice(db, invoice, user.tenant_id, user.id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    await log_action(db, user.tenant_id, user.id, "VOID", "Invoice", invoice_id)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    return {"success": True, "message": "Invoice voided"}


@router.post("/{invoice_id}/payments")
async def add_payment(
    invoice_id: str,
    req: RecordPaymentRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Invoice).where(
            Invoice.id == invoice_id, Invoice.tenant_id == user.tenant_id
        )
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    if invoice.status == InvoiceStatus.VOID:
        raise HTTPException(status_code=400, detail="Cannot pay a voided invoice")
    if invoice.status == InvoiceStatus.DRAFT:
        raise HTTPException(status_code=400, detail="Finalize invoice before recording payment")

    payment = await record_payment(
        db=db,
        invoice=invoice,
        amount=req.amount,
        payment_date=req.payment_date,
        payment_method=req.payment_method,
        reference_number=req.reference_number,
        notes=req.notes,
    )

    await log_action(
        db, user.tenant_id, user.id, "PAYMENT", "Invoice", invoice_id,
        new_values={"amount": req.amount, "method": req.payment_method},
    )
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)

    return {
        "success": True,
        "data": PaymentResponse.model_validate(payment),
        "message": f"Payment of ₦{req.amount:,.2f} recorded",
    }


@router.delete("/{invoice_id}")
async def delete_invoice(
    invoice_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Invoice).where(
            Invoice.id == invoice_id, Invoice.tenant_id == user.tenant_id
        )
    )
    invoice = result.scalar_one_or_none()
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    if invoice.status != InvoiceStatus.DRAFT:
        raise HTTPException(status_code=400, detail="Only draft invoices can be deleted")

    await log_action(db, user.tenant_id, user.id, "DELETE", "Invoice", invoice_id)
    await db.delete(invoice)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    return {"success": True, "message": "Invoice deleted"}
