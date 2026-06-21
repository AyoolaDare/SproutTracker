from datetime import datetime

from pydantic import BaseModel, Field


class CashPositionCreate(BaseModel):
    cash_on_hand: float = Field(default=0, ge=0)
    bank_balance: float = Field(default=0, ge=0)
    notes: str | None = Field(default=None, max_length=1000)


class CashPositionResponse(BaseModel):
    id: str | None = None
    cash_on_hand: float = 0
    bank_balance: float = 0
    total: float = 0
    notes: str | None = None
    recorded_at: datetime | None = None
