from pydantic import BaseModel


class BusinessProfileUpdate(BaseModel):
    business_name: str | None = None
    business_type: str | None = None
    tin: str | None = None
    rc_number: str | None = None
    address: str | None = None
    phone: str | None = None
    email: str | None = None
    website: str | None = None
    logo_url: str | None = None
    bank_name: str | None = None
    bank_account_number: str | None = None
    bank_account_name: str | None = None
    financial_year_start: int | None = None
    accounting_basis: str | None = None
    inventory_enabled: bool | None = None
    vat_registered: bool | None = None


class TaxSettingsUpdate(BaseModel):
    vat_rate: float | None = None
    vat_enabled: bool | None = None
    vat_exempt_categories: list[str] | None = None
    wht_rate_services: float | None = None
    wht_rate_professional: float | None = None
    cit_rate: float | None = None
    is_small_company: bool | None = None
    small_company_cit_rate: float | None = None
    tetfund_rate: float | None = None


class TaxSettingsResponse(BaseModel):
    vat_rate: float
    vat_enabled: bool
    vat_exempt_categories: list[str] | None = None
    wht_rate_services: float
    wht_rate_professional: float
    cit_rate: float
    is_small_company: bool
    small_company_cit_rate: float
    tetfund_rate: float

    model_config = {"from_attributes": True}
