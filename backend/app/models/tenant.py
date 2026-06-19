import uuid
from sqlalchemy import String, Boolean, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base, TimestampMixin
import enum


class BusinessType(str, enum.Enum):
    RETAIL = "RETAIL"
    WHOLESALE = "WHOLESALE"
    SERVICE = "SERVICE"
    MIXED = "MIXED"


class AccountingBasis(str, enum.Enum):
    CASH = "CASH"
    ACCRUAL = "ACCRUAL"


class Tenant(TimestampMixin, Base):
    __tablename__ = "tenants"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    firebase_user_id: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True)
    business_name: Mapped[str] = mapped_column(String(200))
    business_type: Mapped[BusinessType] = mapped_column(
        SAEnum(BusinessType), default=BusinessType.RETAIL
    )
    tin: Mapped[str | None] = mapped_column(String(20), nullable=True)
    rc_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    currency: Mapped[str] = mapped_column(String(3), default="NGN")
    country: Mapped[str] = mapped_column(String(2), default="NG")
    financial_year_start: Mapped[int] = mapped_column(default=1)  # month 1-12
    accounting_basis: Mapped[AccountingBasis] = mapped_column(
        SAEnum(AccountingBasis), default=AccountingBasis.CASH
    )
    inventory_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    vat_registered: Mapped[bool] = mapped_column(Boolean, default=False)

    # Contact
    address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    email: Mapped[str | None] = mapped_column(String(200), nullable=True)
    website: Mapped[str | None] = mapped_column(String(200), nullable=True)
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Bank details (for invoice footer)
    bank_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    bank_account_number: Mapped[str | None] = mapped_column(String(20), nullable=True)
    bank_account_name: Mapped[str | None] = mapped_column(String(200), nullable=True)

    # Relationships
    users = relationship("User", back_populates="tenant", cascade="all, delete-orphan")
    customers = relationship("Customer", back_populates="tenant", cascade="all, delete-orphan")
    products = relationship("Product", back_populates="tenant", cascade="all, delete-orphan")
    invoices = relationship("Invoice", back_populates="tenant", cascade="all, delete-orphan")
    expenses = relationship("Expense", back_populates="tenant", cascade="all, delete-orphan")
    tax_settings = relationship("TaxSettings", back_populates="tenant", uselist=False, cascade="all, delete-orphan")
