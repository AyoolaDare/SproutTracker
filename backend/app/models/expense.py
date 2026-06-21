import uuid
from sqlalchemy import String, Numeric, Boolean, ForeignKey, Text, Date, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base, TimestampMixin, TenantMixin


class Expense(TenantMixin, TimestampMixin, Base):
    __tablename__ = "expenses"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    firestore_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    tenant_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tenants.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    description: Mapped[str] = mapped_column(String(500))
    amount: Mapped[float] = mapped_column(Numeric(15, 2))
    category: Mapped[str] = mapped_column(String(100))
    date: Mapped[str] = mapped_column(Date)
    vendor: Mapped[str | None] = mapped_column(String(200), nullable=True)
    reference_number: Mapped[str | None] = mapped_column(String(100), nullable=True)
    receipt_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    is_tax_deductible: Mapped[bool] = mapped_column(Boolean, default=True)
    is_capital_expenditure: Mapped[bool] = mapped_column(Boolean, default=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # VAT on purchases (input VAT)
    vat_amount: Mapped[float] = mapped_column(Numeric(15, 2), default=0)

    # Relationships
    tenant = relationship("Tenant", back_populates="expenses")
    created_by_user = relationship("User", back_populates="expenses")


class ExpenseBudget(TenantMixin, TimestampMixin, Base):
    __tablename__ = "expense_budgets"
    __table_args__ = (
        UniqueConstraint("tenant_id", "category", "month", name="uq_expense_budget_tenant_category_month"),
    )

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    tenant_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tenants.id", ondelete="CASCADE"), index=True
    )
    category: Mapped[str] = mapped_column(String(100))
    month: Mapped[str] = mapped_column(Date)
    amount: Mapped[float] = mapped_column(Numeric(15, 2))
    alert_threshold_percent: Mapped[float] = mapped_column(Numeric(5, 2), default=80)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
