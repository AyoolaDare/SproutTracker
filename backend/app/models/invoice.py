import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Numeric, Integer, ForeignKey, Text, DateTime, Date, Enum as SAEnum, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base, TimestampMixin, TenantMixin
import enum


class InvoiceStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    SENT = "SENT"
    VIEWED = "VIEWED"
    OVERDUE = "OVERDUE"
    VOID = "VOID"


class PaymentStatus(str, enum.Enum):
    UNPAID = "UNPAID"
    PARTIALLY_PAID = "PARTIALLY_PAID"
    PAID = "PAID"
    OVERPAID = "OVERPAID"


class PaymentMethod(str, enum.Enum):
    CASH = "CASH"
    BANK_TRANSFER = "BANK_TRANSFER"
    CHEQUE = "CHEQUE"
    CARD = "CARD"
    MOBILE_MONEY = "MOBILE_MONEY"
    OTHER = "OTHER"


class Invoice(TenantMixin, TimestampMixin, Base):
    __tablename__ = "invoices"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    firestore_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    tenant_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tenants.id", ondelete="CASCADE"), index=True
    )
    customer_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("customers.id", ondelete="RESTRICT"), index=True
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    invoice_number: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    invoice_date: Mapped[datetime] = mapped_column(Date)
    due_date: Mapped[datetime] = mapped_column(Date)

    # Financials
    subtotal: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    discount_amount: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    discount_type: Mapped[str | None] = mapped_column(String(10), nullable=True)  # "PERCENT" or "FIXED"
    discount_value: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    vat_amount: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    wht_amount: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    total_amount: Mapped[float] = mapped_column(Numeric(15, 2), default=0)

    # COGS from FIFO
    total_cost: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    gross_profit: Mapped[float] = mapped_column(Numeric(15, 2), default=0)

    # Payment tracking
    paid_amount: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    outstanding_amount: Mapped[float] = mapped_column(Numeric(15, 2), default=0)

    # Status
    status: Mapped[InvoiceStatus] = mapped_column(
        SAEnum(InvoiceStatus), default=InvoiceStatus.DRAFT
    )
    payment_status: Mapped[PaymentStatus] = mapped_column(
        SAEnum(PaymentStatus), default=PaymentStatus.UNPAID
    )

    # WHT
    wht_applied: Mapped[bool] = mapped_column(Boolean, default=False)
    wht_certificate_number: Mapped[str | None] = mapped_column(String(50), nullable=True)

    # Extras
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    terms: Mapped[str | None] = mapped_column(Text, nullable=True)
    pdf_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    public_share_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Relationships
    tenant = relationship("Tenant", back_populates="invoices")
    customer = relationship("Customer", back_populates="invoices")
    created_by_user = relationship("User", back_populates="invoices")
    items = relationship("InvoiceItem", back_populates="invoice", cascade="all, delete-orphan")
    payments = relationship("Payment", back_populates="invoice", cascade="all, delete-orphan")


class InvoiceItem(TimestampMixin, Base):
    __tablename__ = "invoice_items"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    invoice_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("invoices.id", ondelete="CASCADE"), index=True
    )
    product_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    description: Mapped[str] = mapped_column(String(500))
    quantity: Mapped[int] = mapped_column(Integer)
    unit_price: Mapped[float] = mapped_column(Numeric(15, 2))
    line_total: Mapped[float] = mapped_column(Numeric(15, 2))

    # FIFO cost
    unit_cost: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    total_cost: Mapped[float] = mapped_column(Numeric(15, 2), default=0)
    line_profit: Mapped[float] = mapped_column(Numeric(15, 2), default=0)

    # Tax
    vat_rate: Mapped[float] = mapped_column(Numeric(5, 4), default=0)
    vat_amount: Mapped[float] = mapped_column(Numeric(15, 2), default=0)

    # Relationships
    invoice = relationship("Invoice", back_populates="items")
    product = relationship("Product", back_populates="invoice_items")
    batch_allocations = relationship("BatchAllocation", back_populates="invoice_item", cascade="all, delete-orphan")


class Payment(TimestampMixin, Base):
    __tablename__ = "payments"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    invoice_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("invoices.id", ondelete="CASCADE"), index=True
    )
    amount: Mapped[float] = mapped_column(Numeric(15, 2))
    payment_date: Mapped[datetime] = mapped_column(Date)
    payment_method: Mapped[PaymentMethod] = mapped_column(SAEnum(PaymentMethod))
    reference_number: Mapped[str | None] = mapped_column(String(100), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Relationships
    invoice = relationship("Invoice", back_populates="payments")
