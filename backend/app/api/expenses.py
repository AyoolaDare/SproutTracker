from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
from sqlalchemy.dialects.postgresql import insert
from app.database import get_db
from app.models.user import User
from app.models.expense import Expense, ExpenseBudget
from app.middleware.auth import get_current_user
from app.schemas.expense import (
    ExpenseBudgetResponse,
    ExpenseBudgetUpsert,
    ExpenseCreate,
    ExpenseResponse,
    ExpenseUpdate,
)
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
async def get_categories(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    custom_result = await db.execute(
        select(Expense.category)
        .where(Expense.tenant_id == user.tenant_id)
        .where(Expense.category.isnot(None))
        .group_by(Expense.category)
        .order_by(Expense.category)
    )
    categories = sorted({*EXPENSE_CATEGORIES, *[c for c in custom_result.scalars().all() if c]})
    return {"success": True, "data": categories}


@router.get("/budgets")
async def list_budgets(
    month: date | None = None,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    target = month or date.today()
    month_start = date(target.year, target.month, 1)
    budgets_result = await db.execute(
        select(ExpenseBudget).where(
            ExpenseBudget.tenant_id == user.tenant_id,
            ExpenseBudget.month == month_start,
        ).order_by(ExpenseBudget.category)
    )
    budgets = budgets_result.scalars().all()
    actual_result = await db.execute(
        select(Expense.category, func.coalesce(func.sum(Expense.amount), 0))
        .where(
            Expense.tenant_id == user.tenant_id,
            Expense.date >= month_start,
            Expense.date < date(month_start.year + (1 if month_start.month == 12 else 0), 1 if month_start.month == 12 else month_start.month + 1, 1),
        )
        .group_by(Expense.category)
    )
    actuals = {row[0]: float(row[1] or 0) for row in actual_result.all()}

    rows = []
    for budget in budgets:
        actual = actuals.get(budget.category, 0)
        amount = float(budget.amount)
        usage = (actual / amount * 100) if amount > 0 else 0
        threshold = float(budget.alert_threshold_percent or 80)
        status = "OVER_BUDGET" if usage >= 100 else ("WATCH" if usage >= threshold else "ON_TRACK")
        rows.append(ExpenseBudgetResponse(
            id=budget.id,
            category=budget.category,
            month=budget.month,
            amount=amount,
            actual_amount=round(actual, 2),
            usage_percent=round(usage, 1),
            alert_threshold_percent=threshold,
            is_active=budget.is_active,
            status=status,
        ))
    return {"success": True, "data": rows}


@router.put("/budgets")
async def upsert_budget(
    req: ExpenseBudgetUpsert,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    month_start = date(req.month.year, req.month.month, 1)
    values = {
        "tenant_id": user.tenant_id,
        "category": req.category.strip(),
        "month": month_start,
        "amount": req.amount,
        "alert_threshold_percent": req.alert_threshold_percent,
        "is_active": req.is_active,
    }
    stmt = (
        insert(ExpenseBudget)
        .values(**values)
        .on_conflict_do_update(
            constraint="uq_expense_budget_tenant_category_month",
            set_={
                "amount": req.amount,
                "alert_threshold_percent": req.alert_threshold_percent,
                "is_active": req.is_active,
            },
        )
        .returning(ExpenseBudget)
    )
    result = await db.execute(stmt)
    budget = result.scalar_one()
    await log_action(
        db,
        user.tenant_id,
        user.id,
        "UPSERT",
        "ExpenseBudget",
        budget.id,
        new_values={**values, "month": month_start.isoformat()},
    )
    await db.commit()
    await invalidate_tenant_dashboard(user.tenant_id)
    return {"success": True, "data": ExpenseBudgetResponse(
        id=budget.id,
        category=budget.category,
        month=budget.month,
        amount=float(budget.amount),
        actual_amount=0,
        usage_percent=0,
        alert_threshold_percent=float(budget.alert_threshold_percent or 80),
        is_active=budget.is_active,
        status="ON_TRACK",
    )}


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
    await db.flush()
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
