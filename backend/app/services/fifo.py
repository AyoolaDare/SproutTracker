"""
FIFO (First In, First Out) Inventory Allocation Engine.

Core business logic:
- When stock is received, a new InventoryBatch is created with locked unit_cost
- When stock is sold (invoice finalized), oldest batches are consumed first
- Each allocation is tracked in BatchAllocation for full audit trail
- COGS is calculated from actual batch costs, not averages
"""

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.inventory import InventoryBatch, BatchAllocation, StockMovement, MovementType
from app.models.product import Product


class InsufficientStockError(Exception):
    def __init__(self, product_name: str, available: int, requested: int):
        self.product_name = product_name
        self.available = available
        self.requested = requested
        super().__init__(
            f"Insufficient stock for '{product_name}': "
            f"available={available}, requested={requested}"
        )


class FIFOAllocationResult:
    def __init__(self):
        self.allocations: list[dict] = []
        self.total_cost: float = 0
        self.weighted_avg_cost: float = 0

    def add(self, batch_id: str, quantity: int, unit_cost: float):
        total = quantity * unit_cost
        self.allocations.append({
            "batch_id": batch_id,
            "quantity": quantity,
            "unit_cost": unit_cost,
            "total_cost": total,
        })
        self.total_cost += total

    def finalize(self, total_quantity: int):
        self.weighted_avg_cost = (
            self.total_cost / total_quantity if total_quantity > 0 else 0
        )


async def allocate_fifo(
    db: AsyncSession,
    tenant_id: str,
    product_id: str,
    quantity_needed: int,
) -> FIFOAllocationResult:
    """
    Allocate inventory using FIFO (oldest batches first).

    Returns allocation details with cost breakdown.
    Does NOT commit — caller is responsible for the transaction.
    """
    # Get available batches ordered by date received (oldest first)
    result = await db.execute(
        select(InventoryBatch)
        .where(
            InventoryBatch.tenant_id == tenant_id,
            InventoryBatch.product_id == product_id,
            InventoryBatch.remaining_quantity > 0,
            InventoryBatch.is_exhausted == False,
        )
        .order_by(InventoryBatch.date_received.asc())
    )
    batches = result.scalars().all()

    # Check total available
    total_available = sum(b.remaining_quantity for b in batches)
    if total_available < quantity_needed:
        # Get product name for error message
        prod_result = await db.execute(
            select(Product.name).where(
                Product.id == product_id,
                Product.tenant_id == tenant_id,
            )
        )
        product_name = prod_result.scalar_one_or_none() or "Unknown"
        raise InsufficientStockError(product_name, total_available, quantity_needed)

    # Allocate from oldest batches first
    allocation = FIFOAllocationResult()
    remaining = quantity_needed

    for batch in batches:
        if remaining <= 0:
            break

        allocate_qty = min(batch.remaining_quantity, remaining)
        allocation.add(
            batch_id=batch.id,
            quantity=allocate_qty,
            unit_cost=float(batch.unit_cost),
        )

        # Deduct from batch
        batch.remaining_quantity -= allocate_qty
        if batch.remaining_quantity == 0:
            batch.is_exhausted = True

        remaining -= allocate_qty

    allocation.finalize(quantity_needed)
    return allocation


async def create_batch_allocations(
    db: AsyncSession,
    invoice_item_id: str,
    allocation_result: FIFOAllocationResult,
) -> list[BatchAllocation]:
    """Create BatchAllocation records for audit trail."""
    records = []
    for alloc in allocation_result.allocations:
        record = BatchAllocation(
            invoice_item_id=invoice_item_id,
            batch_id=alloc["batch_id"],
            quantity_allocated=alloc["quantity"],
            unit_cost=alloc["unit_cost"],
            total_cost=alloc["total_cost"],
        )
        db.add(record)
        records.append(record)
    return records


async def reverse_fifo_allocation(
    db: AsyncSession,
    invoice_item_id: str,
):
    """Reverse FIFO allocations when an invoice is voided."""
    result = await db.execute(
        select(BatchAllocation).where(
            BatchAllocation.invoice_item_id == invoice_item_id
        )
    )
    allocations = result.scalars().all()

    for alloc in allocations:
        # Restore batch quantities
        batch_result = await db.execute(
            select(InventoryBatch).where(InventoryBatch.id == alloc.batch_id)
        )
        batch = batch_result.scalar_one_or_none()
        if batch:
            batch.remaining_quantity += alloc.quantity_allocated
            batch.is_exhausted = False

        # Delete the allocation record
        await db.delete(alloc)


async def receive_stock(
    db: AsyncSession,
    tenant_id: str,
    product_id: str,
    quantity: int,
    unit_cost: float,
    user_id: str | None = None,
    date_received=None,
    batch_number: str | None = None,
    supplier_ref: str | None = None,
    notes: str | None = None,
) -> InventoryBatch:
    """Create a new inventory batch (stock receipt)."""
    from datetime import datetime, timezone

    batch = InventoryBatch(
        tenant_id=tenant_id,
        product_id=product_id,
        unit_cost=unit_cost,
        initial_quantity=quantity,
        remaining_quantity=quantity,
        date_received=date_received or datetime.now(timezone.utc),
        batch_number=batch_number,
        supplier_ref=supplier_ref,
    )
    db.add(batch)

    # Create stock movement record
    movement = StockMovement(
        tenant_id=tenant_id,
        product_id=product_id,
        movement_type=MovementType.PURCHASE,
        quantity=quantity,
        unit_value=unit_cost,
        total_value=quantity * unit_cost,
        reference_type="BATCH",
        reference_id=batch.id,
        user_id=user_id,
        notes=notes or f"Stock received: {quantity} units @ ₦{unit_cost:,.2f}",
    )
    db.add(movement)

    return batch


async def adjust_stock(
    db: AsyncSession,
    tenant_id: str,
    product_id: str,
    quantity: int,
    reason: str,
    user_id: str | None = None,
    notes: str | None = None,
):
    """Adjust stock levels. Positive = increase, negative = decrease."""
    if quantity > 0:
        # For increases, create a new batch with zero cost (adjustment)
        batch = InventoryBatch(
            tenant_id=tenant_id,
            product_id=product_id,
            unit_cost=0,
            initial_quantity=quantity,
            remaining_quantity=quantity,
            batch_number=f"ADJ-{reason[:20]}",
        )
        db.add(batch)
    else:
        # For decreases, consume from oldest batches (FIFO)
        result = await db.execute(
            select(InventoryBatch)
            .where(
                InventoryBatch.tenant_id == tenant_id,
                InventoryBatch.product_id == product_id,
                InventoryBatch.remaining_quantity > 0,
            )
            .order_by(InventoryBatch.date_received.asc())
        )
        batches = result.scalars().all()

        remaining = abs(quantity)
        for batch in batches:
            if remaining <= 0:
                break
            deduct = min(batch.remaining_quantity, remaining)
            batch.remaining_quantity -= deduct
            if batch.remaining_quantity == 0:
                batch.is_exhausted = True
            remaining -= deduct

    movement_type = MovementType.ADJUSTMENT
    if reason.upper() == "DAMAGE":
        movement_type = MovementType.DAMAGE
    elif reason.upper() == "RETURN":
        movement_type = MovementType.RETURN

    movement = StockMovement(
        tenant_id=tenant_id,
        product_id=product_id,
        movement_type=movement_type,
        quantity=quantity,
        unit_value=0,
        total_value=0,
        reference_type="ADJUSTMENT",
        user_id=user_id,
        notes=notes or f"Stock adjustment: {quantity} ({reason})",
    )
    db.add(movement)
