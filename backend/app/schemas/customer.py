from pydantic import BaseModel, Field
from datetime import datetime


class CustomerCreate(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    email: str | None = None
    phone: str | None = None
    address: str | None = None
    company: str | None = None
    tin: str | None = None
    is_wht_applicable: bool = False
    notes: str | None = None


class CustomerUpdate(BaseModel):
    name: str | None = None
    email: str | None = None
    phone: str | None = None
    address: str | None = None
    company: str | None = None
    tin: str | None = None
    is_wht_applicable: bool | None = None
    status: str | None = None
    notes: str | None = None


class CustomerResponse(BaseModel):
    id: str
    name: str
    email: str | None = None
    phone: str | None = None
    address: str | None = None
    company: str | None = None
    tin: str | None = None
    total_revenue: float = 0
    outstanding_balance: float = 0
    total_paid: float = 0
    is_wht_applicable: bool = False
    status: str = "ACTIVE"
    notes: str | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}
