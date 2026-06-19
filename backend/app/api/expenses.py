from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from app.database import get_db
from app.models.user import User
from app.models.expense import Expense
from app.middleware.auth import get_current_user
from app.schemas.expense import ExpenseCreate, ExpenseUpdate, ExpenseResponse
from app.services.audit import log_action
from app.services.cache import invalidate_tenant_dashboard

router = APIRouter(prefix="/api/expenses", tags=["Expenses"])

EXPENSE_CATEGORIES = [
    "Rent",
    "Utilities",
    "Salaries",
    "Transportation",
    "Marketing & Advertising",
    "Supplies & Materials",
    "Professional Fees",
    "Insurance",
    "Repairs & Maintenance",
    "Taxes & Licenses",
    "Depreciation",
    "Bank Charges",
    "Technology & Subscriptions",
    "Other",
]


@router.get("")
async def list_expenses(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = None,
    category: str | None = None,
    is_tax_deductible: bool | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    query = select(Expense).where(Expense.tenant_id == user.tenant_id)

    if search:
        query = query.where(
            or_(
                Expense.description.ilike(f"%{search}%"),
                Expense.vendor.ilike(f"%{search}%"),
            )
        )
    if category:
        query = query.where(Expense.category == category)
    if is_tax_deductible is not None:
        query = query.where(Expense.is_tax_deductible == is_tax_deductible)

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    query = query.order_by(Expense.date.desc())
    query = query.offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    expenses = result.scalars().all()

    return {
        "success": True,
        "data": [ExpenseResponse.model_validate(e) for e in expenses],
        "pagination": {
            "page": page,
            "limit": limit,
            "total": total,
            "total_pages": (total + limit - 1) // limit,
        },
    }


@router.get("/categories")
async def get_categories():
    return {"success": True, "data": EXPENSE_CATEGORIES}


@router.get("/{expense_id}", response_model=ExpenseResponse)
async def get_expense(
    expense_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Expense).where(
            Expense.id == expense_id, Expense.tenant_id == user.tenant_id
        )
    )
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    return ExpenseResponse.model_validate(expense)


@router.post("", status_code=201)
async def create_expense(
    req: ExpenseCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    expense = Expense(
        tenant_id=user.tenant_id,
        user_id=user.id,
        **req.model_dump(),
    )
    db.add(expense)
    await log_action(db, user.tenant_id, user.id, "CREATE", "Expense", expense.id,
                     new_values=req.model_dump(mode="json"))
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    await db.refresh(expense)
    return {"success": True, "data": ExpenseResponse.model_validate(expense)}


@router.put("/{expense_id}")
async def update_expense(
    expense_id: str,
    req: ExpenseUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Expense).where(
            Expense.id == expense_id, Expense.tenant_id == user.tenant_id
        )
    )
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    updates = req.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(expense, key, value)

    await log_action(db, user.tenant_id, user.id, "UPDATE", "Expense", expense_id,
                     new_values=updates)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    await db.refresh(expense)
    return {"success": True, "data": ExpenseResponse.model_validate(expense)}


@router.delete("/{expense_id}")
async def delete_expense(
    expense_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Expense).where(
            Expense.id == expense_id, Expense.tenant_id == user.tenant_id
        )
    )
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    await log_action(db, user.tenant_id, user.id, "DELETE", "Expense", expense_id)
    await db.delete(expense)
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    return {"success": True, "message": "Expense deleted"}
