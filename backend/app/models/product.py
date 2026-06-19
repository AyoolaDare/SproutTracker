import uuid
from sqlalchemy import String, Boolean, Numeric, Integer, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base, TimestampMixin, TenantMixin


class Product(TenantMixin, TimestampMixin, Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    firestore_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    tenant_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tenants.id", ondelete="CASCADE"), index=True
    )
    name: Mapped[str] = mapped_column(String(200))
    sku: Mapped[str] = mapped_column(String(50), index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    selling_price: Mapped[float] = mapped_column(Numeric(15, 2))
    track_inventory: Mapped[bool] = mapped_column(Boolean, default=True)
    reorder_level: Mapped[int] = mapped_column(Integer, default=0)
    vat_applicable: Mapped[bool] = mapped_column(Boolean, default=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Relationships
    tenant = relationship("Tenant", back_populates="products")
    batches = relationship("InventoryBatch", back_populates="product", cascade="all, delete-orphan")
    invoice_items = relationship("InvoiceItem", back_populates="product")
    stock_movements = relationship("StockMovement", back_populates="product", cascade="all, delete-orphan")

    @property
    def current_stock(self) -> int:
        return sum(b.remaining_quantity for b in self.batches if not b.is_exhausted)

    @property
    def average_cost(self) -> float:
        active = [b for b in self.batches if b.remaining_quantity > 0]
        if not active:
            return 0
        total_qty = sum(b.remaining_quantity for b in active)
        total_cost = sum(b.remaining_quantity * float(b.unit_cost) for b in active)
        return total_cost / total_qty if total_qty > 0 else 0
