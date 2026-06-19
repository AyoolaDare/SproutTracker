from pydantic import BaseModel, Field
from datetime import date as Date, datetime as DateTime


class ExpenseCreate(BaseModel):
    description: str = Field(min_length=2, max_length=500)
    amount: float = Field(gt=0)
    category: str
    date: Date
    vendor: str | None = None
    reference_number: str | None = None
    is_tax_deductible: bool = True
    is_capital_expenditure: bool = False
    notes: str | None = None
    vat_amount: float = 0


class ExpenseUpdate(BaseModel):
    description: str | None = None
    amount: float | None = None
    category: str | None = None
    date: Date | None = None
    vendor: str | None = None
    reference_number: str | None = None
    receipt_url: str | None = None
    is_tax_deductible: bool | None = None
    is_capital_expenditure: bool | None = None
    notes: str | None = None
    vat_amount: float | None = None


class ExpenseResponse(BaseModel):
    id: str
    description: str
    amount: float
    category: str
    date: Date
    vendor: str | None = None
    reference_number: str | None = None
    receipt_url: str | None = None
    is_tax_deductible: bool
    is_capital_expenditure: bool
    vat_amount: float = 0
    notes: str | None = None
    created_at: DateTime | None = None

    model_config = {"from_attributes": True}
