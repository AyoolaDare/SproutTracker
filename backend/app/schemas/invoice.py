from pydantic import BaseModel, Field
from datetime import date as Date, datetime as DateTime


class InvoiceItemCreate(BaseModel):
    product_id: str | None = None
    description: str = Field(min_length=1, max_length=500)
    quantity: int = Field(gt=0)
    unit_price: float = Field(gt=0)


class InvoiceCreate(BaseModel):
    customer_id: str
    invoice_date: Date
    due_date: Date
    items: list[InvoiceItemCreate] = Field(min_length=1)
    discount_type: str | None = None  # "PERCENT" or "FIXED"
    discount_value: float = 0
    notes: str | None = None
    terms: str | None = None
    apply_vat: bool = True
    apply_wht: bool = False


class InvoiceUpdate(BaseModel):
    customer_id: str | None = None
    invoice_date: Date | None = None
    due_date: Date | None = None
    items: list[InvoiceItemCreate] | None = None
    discount_type: str | None = None
    discount_value: float | None = None
    notes: str | None = None
    terms: str | None = None
    apply_vat: bool | None = None
    apply_wht: bool | None = None


class RecordPaymentRequest(BaseModel):
    amount: float = Field(gt=0)
    payment_date: Date
    payment_method: str
    reference_number: str | None = None
    notes: str | None = None


class InvoiceItemResponse(BaseModel):
    id: str
    product_id: str | None = None
    description: str
    quantity: int
    unit_price: float
    line_total: float
    unit_cost: float = 0
    total_cost: float = 0
    line_profit: float = 0
    vat_rate: float = 0
    vat_amount: float = 0

    model_config = {"from_attributes": True}


class PaymentResponse(BaseModel):
    id: str
    amount: float
    payment_date: Date
    payment_method: str
    reference_number: str | None = None
    notes: str | None = None
    created_at: DateTime | None = None

    model_config = {"from_attributes": True}


class InvoiceResponse(BaseModel):
    id: str
    invoice_number: str
    customer_id: str
    customer_name: str | None = None
    invoice_date: Date
    due_date: Date
    subtotal: float
    discount_amount: float = 0
    vat_amount: float = 0
    wht_amount: float = 0
    total_amount: float
    total_cost: float = 0
    gross_profit: float = 0
    paid_amount: float = 0
    outstanding_amount: float = 0
    status: str
    payment_status: str
    wht_applied: bool = False
    notes: str | None = None
    terms: str | None = None
    items: list[InvoiceItemResponse] = []
    payments: list[PaymentResponse] = []
    created_at: DateTime | None = None

    model_config = {"from_attributes": True}
