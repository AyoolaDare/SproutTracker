import uuid
from sqlalchemy import String, Numeric, Boolean, ForeignKey, JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base, TimestampMixin


class TaxSettings(TimestampMixin, Base):
    __tablename__ = "tax_settings"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    tenant_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tenants.id", ondelete="CASCADE"), unique=True
    )

    # VAT
    vat_rate: Mapped[float] = mapped_column(Numeric(5, 4), default=0.075)
    vat_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    vat_exempt_categories: Mapped[list | None] = mapped_column(JSON, nullable=True)
    # Default exemptions: basic-food, medical, educational

    # WHT
    wht_rate_services: Mapped[float] = mapped_column(Numeric(5, 4), default=0.05)
    wht_rate_professional: Mapped[float] = mapped_column(Numeric(5, 4), default=0.10)

    # CIT
    cit_rate: Mapped[float] = mapped_column(Numeric(5, 4), default=0.30)
    is_small_company: Mapped[bool] = mapped_column(Boolean, default=True)
    small_company_cit_rate: Mapped[float] = mapped_column(Numeric(5, 4), default=0.20)

    # TETFund
    tetfund_rate: Mapped[float] = mapped_column(Numeric(5, 4), default=0.025)

    # Relationships
    tenant = relationship("Tenant", back_populates="tax_settings")
