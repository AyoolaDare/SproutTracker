from pydantic import BaseModel, Field
from datetime import datetime


class ProductCreate(BaseModel):
    name: str = Field(min_length=2, max_length=200)
    sku: str | None = Field(default=None, min_length=1, max_length=50)
    description: str | None = None
    category: str | None = None
    selling_price: float = Field(gt=0)
    track_inventory: bool = True
    reorder_level: int = Field(ge=0, default=0)
    vat_applicable: bool = True


class ProductUpdate(BaseModel):
    name: str | None = None
    sku: str | None = None
    description: str | None = None
    category: str | None = None
    selling_price: float | None = None
    track_inventory: bool | None = None
    reorder_level: int | None = None
    vat_applicable: bool | None = None
    is_active: bool | None = None


class ProductResponse(BaseModel):
    id: str
    name: str
    sku: str
    description: str | None = None
    category: str | None = None
    selling_price: float
    track_inventory: bool
    reorder_level: int
    vat_applicable: bool
    is_active: bool
    current_stock: int = 0
    average_cost: float = 0
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class ReceiveStockRequest(BaseModel):
    product_id: str
    quantity: int = Field(gt=0)
    unit_cost: float = Field(gt=0)
    date_received: datetime | None = None
    batch_number: str | None = None
    supplier_ref: str | None = None
    notes: str | None = None


class AdjustStockRequest(BaseModel):
    product_id: str
    quantity: int  # positive=increase, negative=decrease
    reason: str = Field(min_length=2)
    notes: str | None = None


class StockMovementResponse(BaseModel):
    id: str
    product_id: str
    product_name: str | None = None
    movement_type: str
    quantity: int
    unit_value: float
    total_value: float
    reference_type: str | None = None
    reference_id: str | None = None
    notes: str | None = None
    created_at: datetime | None = None

    model_config = {"from_attributes": True}
