from pydantic import BaseModel
from typing import Any


class APIResponse(BaseModel):
    success: bool = True
    data: Any = None
    message: str | None = None


class PaginatedResponse(BaseModel):
    success: bool = True
    data: list[Any]
    pagination: dict


class PaginationParams(BaseModel):
    page: int = 1
    limit: int = 20
    search: str | None = None
    sort_by: str | None = None
    sort_order: str = "desc"
