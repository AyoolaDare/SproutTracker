import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Boolean, Numeric, Integer, ForeignKey, Text, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base, TimestampMixin, TenantMixin
import enum


class MovementType(str, enum.Enum):
    PURCHASE = "PURCHASE"
    SALE = "SALE"
    ADJUSTMENT = "ADJUSTMENT"
    RETURN = "RETURN"
    DAMAGE = "DAMAGE"


class InventoryBatch(TenantMixin, TimestampMixin, Base):
    """Tracks individual purchase batches for FIFO costing."""
    __tablename__ = "inventory_batches"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    firestore_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    tenant_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tenants.id", ondelete="CASCADE"), index=True
    )
    product_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("products.id", ondelete="CASCADE"), index=True
    )
    unit_cost: Mapped[float] = mapped_column(Numeric(15, 2))
    initial_quantity: Mapped[int] = mapped_column(Integer)
    remaining_quantity: Mapped[int] = mapped_column(Integer)
    date_received: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    batch_number: Mapped[str | None] = mapped_column(String(50), nullable=True)
    supplier_ref: Mapped[str | None] = mapped_column(String(200), nullable=True)
    is_exhausted: Mapped[bool] = mapped_column(Boolean, default=False)

    # Relationships
    product = relationship("Product", back_populates="batches")
    allocations = relationship("BatchAllocation", back_populates="batch")


class BatchAllocation(TimestampMixin, Base):
    """Tracks which batches were consumed for each invoice line item (FIFO audit trail)."""
    __tablename__ = "batch_allocations"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    invoice_item_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("invoice_items.id", ondelete="CASCADE"), index=True
    )
    batch_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("inventory_batches.id", ondelete="CASCADE"), index=True
    )
    quantity_allocated: Mapped[int] = mapped_column(Integer)
    unit_cost: Mapped[float] = mapped_column(Numeric(15, 2))
    total_cost: Mapped[float] = mapped_column(Numeric(15, 2))

    # Relationships
    invoice_item = relationship("InvoiceItem", back_populates="batch_allocations")
    batch = relationship("InventoryBatch", back_populates="allocations")


class StockMovement(TenantMixin, TimestampMixin, Base):
    """Audit trail for all inventory changes."""
    __tablename__ = "stock_movements"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    firestore_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    tenant_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tenants.id", ondelete="CASCADE"), index=True
    )
    product_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("products.id", ondelete="CASCADE"), index=True
    )
    movement_type: Mapped[MovementType] = mapped_column(SAEnum(MovementType))
    quantity: Mapped[int] = mapped_column(Integer)  # positive=add, negative=deduct
    unit_value: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    total_value: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    reference_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    reference_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    user_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Relationships
    product = relationship("Product", back_populates="stock_movements")
