from datetime import date, timedelta
from calendar import monthrange
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.user import User
from app.models.invoice import Invoice, InvoiceItem, InvoiceStatus, Payment
from app.models.expense import Expense
from app.models.customer import Customer
from app.models.product import Product
from app.models.inventory import InventoryBatch
from app.models.tax import TaxSettings
from app.middleware.auth import get_current_user
from app.services.tax import calculate_cit
from app.core.redis import cache_get_json, cache_set_json, redis_key
from app.config import get_settings

router = APIRouter(prefix="/api/dashboard", tags=["Dashboard"])
settings = get_settings()


@router.get("/metrics")
async def get_metrics(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    tid = user.tenant_id
    cache_key = redis_key("dashboard", tid, "metrics")
    cached = await cache_get_json(cache_key)
    if cached is not None:
        return cached

    today = date.today()
    month_start = date(today.year, today.month, 1)
    _, last_day = monthrange(today.year, today.month)
    month_end = date(today.year, today.month, last_day)

    # Last month for comparison
    if today.month == 1:
        last_month_start = date(today.year - 1, 12, 1)
        last_month_end = date(today.year - 1, 12, 31)
    else:
        last_month_start = date(today.year, today.month - 1, 1)
        _, lm_last = monthrange(today.year, today.month - 1)
        last_month_end = date(today.year, today.month - 1, lm_last)

    # --- Revenue this month ---
    inv_result = await db.execute(
        select(Invoice).where(
            Invoice.tenant_id == tid,
            Invoice.status.notin_([InvoiceStatus.DRAFT, InvoiceStatus.VOID]),
            Invoice.invoice_date >= month_start,
            Invoice.invoice_date <= month_end,
        )
    )
    invoices_this_month = inv_result.scalars().all()
    revenue_this_month = sum(float(i.total_amount) for i in invoices_this_month)
    cogs_this_month = sum(float(i.total_cost) for i in invoices_this_month)
    vat_this_month = sum(float(i.vat_amount) for i in invoices_this_month)

    # Last month revenue
    lm_result = await db.execute(
        select(func.coalesce(func.sum(Invoice.total_amount), 0)).where(
            Invoice.tenant_id == tid,
            Invoice.status.notin_([InvoiceStatus.DRAFT, InvoiceStatus.VOID]),
            Invoice.invoice_date >= last_month_start,
            Invoice.invoice_date <= last_month_end,
        )
    )
    revenue_last_month = float(lm_result.scalar() or 0)
    revenue_change = (
        round(((revenue_this_month - revenue_last_month) / revenue_last_month * 100), 1)
        if revenue_last_month > 0 else 0
    )

    # --- Expenses this month ---
    exp_result = await db.execute(
        select(func.coalesce(func.sum(Expense.amount), 0)).where(
            Expense.tenant_id == tid,
            Expense.date >= month_start,
            Expense.date <= month_end,
        )
    )
    expenses_this_month = float(exp_result.scalar() or 0)

    # Input VAT
    input_vat_result = await db.execute(
        select(func.coalesce(func.sum(Expense.vat_amount), 0)).where(
            Expense.tenant_id == tid,
            Expense.date >= month_start,
            Expense.date <= month_end,
        )
    )
    input_vat = float(input_vat_result.scalar() or 0)

    net_profit = revenue_this_month - cogs_this_month - expenses_this_month
    net_margin = round(net_profit / revenue_this_month * 100, 1) if revenue_this_month > 0 else 0

    # --- Outstanding invoices ---
    outstanding_result = await db.execute(
        select(
            func.coalesce(func.sum(Invoice.outstanding_amount), 0),
            func.count(Invoice.id),
        ).where(
            Invoice.tenant_id == tid,
            Invoice.status.notin_([InvoiceStatus.DRAFT, InvoiceStatus.VOID]),
            Invoice.outstanding_amount > 0,
        )
    )
    row = outstanding_result.one()
    outstanding_amount = float(row[0])
    outstanding_count = row[1]

    # --- Inventory value ---
    batch_result = await db.execute(
        select(
            func.coalesce(func.sum(InventoryBatch.remaining_quantity * InventoryBatch.unit_cost), 0)
        ).where(
            InventoryBatch.tenant_id == tid,
            InventoryBatch.remaining_quantity > 0,
        )
    )
    inventory_value = float(batch_result.scalar() or 0)

    # --- Tax summary ---
    net_vat_payable = vat_this_month - input_vat
    tax_result = await db.execute(
        select(TaxSettings).where(TaxSettings.tenant_id == tid)
    )
    tax_settings = tax_result.scalar_one_or_none()
    cit_estimate = 0
    if tax_settings and net_profit > 0:
        cit_data = calculate_cit(
            net_profit,
            is_small_company=tax_settings.is_small_company,
            cit_rate=float(tax_settings.cit_rate),
            small_company_cit_rate=float(tax_settings.small_company_cit_rate),
        )
        cit_estimate = cit_data["total"]

    # --- Revenue trend (last 6 months) ---
    revenue_trend = []
    for i in range(5, -1, -1):
        m = today.month - i
        y = today.year
        if m <= 0:
            m += 12
            y -= 1
        _, ld = monthrange(y, m)
        ms = date(y, m, 1)
        me = date(y, m, ld)
        r = await db.execute(
            select(func.coalesce(func.sum(Invoice.total_amount), 0)).where(
                Invoice.tenant_id == tid,
                Invoice.status.notin_([InvoiceStatus.DRAFT, InvoiceStatus.VOID]),
                Invoice.invoice_date >= ms,
                Invoice.invoice_date <= me,
            )
        )
        revenue_trend.append({"month": ms.strftime("%b %Y"), "revenue": float(r.scalar() or 0)})

    # --- Expense breakdown (this month) ---
    cat_result = await db.execute(
        select(Expense.category, func.sum(Expense.amount)).where(
            Expense.tenant_id == tid,
            Expense.date >= month_start,
            Expense.date <= month_end,
        ).group_by(Expense.category)
    )
    expense_breakdown = [
        {"category": row[0], "amount": float(row[1])}
        for row in cat_result.all()
    ]

    # --- Top selling products (this month) ---
    top_result = await db.execute(
        select(
            InvoiceItem.description,
            func.sum(InvoiceItem.quantity).label("qty"),
            func.sum(InvoiceItem.line_total).label("rev"),
        )
        .join(Invoice)
        .where(
            Invoice.tenant_id == tid,
            Invoice.status.notin_([InvoiceStatus.DRAFT, InvoiceStatus.VOID]),
            Invoice.invoice_date >= month_start,
            Invoice.invoice_date <= month_end,
        )
        .group_by(InvoiceItem.description)
        .order_by(func.sum(InvoiceItem.line_total).desc())
        .limit(5)
    )
    top_products = [
        {"name": row[0], "quantity": int(row[1]), "revenue": float(row[2])}
        for row in top_result.all()
    ]

    # --- Cash flow (last 6 months) ---
    cash_flow = []
    for i in range(5, -1, -1):
        m = today.month - i
        y = today.year
        if m <= 0:
            m += 12
            y -= 1
        _, ld = monthrange(y, m)
        ms = date(y, m, 1)
        me = date(y, m, ld)

        inflow_r = await db.execute(
            select(func.coalesce(func.sum(Payment.amount), 0))
            .join(Invoice)
            .where(
                Invoice.tenant_id == tid,
                Payment.payment_date >= ms,
                Payment.payment_date <= me,
            )
        )
        outflow_r = await db.execute(
            select(func.coalesce(func.sum(Expense.amount), 0)).where(
                Expense.tenant_id == tid,
                Expense.date >= ms,
                Expense.date <= me,
            )
        )
        cash_flow.append({
            "month": ms.strftime("%b %Y"),
            "inflow": float(inflow_r.scalar() or 0),
            "outflow": float(outflow_r.scalar() or 0),
        })

    # --- Expenses last month ---
    exp_lm_result = await db.execute(
        select(func.coalesce(func.sum(Expense.amount), 0)).where(
            Expense.tenant_id == tid,
            Expense.date >= last_month_start,
            Expense.date <= last_month_end,
        )
    )
    expenses_last_month = float(exp_lm_result.scalar() or 0)

    # --- Recent expenses ---
    recent_exp_result = await db.execute(
        select(Expense)
        .where(Expense.tenant_id == tid)
        .order_by(Expense.date.desc())
        .limit(5)
    )
    recent_expenses = [
        {
            "id": e.id,
            "description": e.description,
            "amount": float(e.amount),
            "category": e.category or "Other",
        }
        for e in recent_exp_result.scalars().all()
    ]

    # --- Recent invoices ---
    recent_result = await db.execute(
        select(Invoice)
        .options(selectinload(Invoice.customer))
        .where(Invoice.tenant_id == tid)
        .order_by(Invoice.created_at.desc())
        .limit(10)
    )
    recent_invoices = [
        {
            "id": i.id,
            "invoice_number": i.invoice_number,
            "customer_name": i.customer.name if i.customer else "Unknown",
            "total_amount": float(i.total_amount),
            "status": i.status.value,
            "payment_status": i.payment_status.value,
            "invoice_date": i.invoice_date.isoformat(),
        }
        for i in recent_result.scalars().unique().all()
    ]

    # --- Low stock alerts ---
    low_result = await db.execute(
        select(Product)
        .options(selectinload(Product.batches))
        .where(
            Product.tenant_id == tid,
            Product.is_active == True,
            Product.track_inventory == True,
        )
    )
    low_stock_alerts = []
    for p in low_result.scalars().unique().all():
        stock = sum(b.remaining_quantity for b in p.batches if not b.is_exhausted)
        if stock <= p.reorder_level:
            low_stock_alerts.append({
                "product_id": p.id,
                "product_name": p.name,
                "current_stock": stock,
                "reorder_level": p.reorder_level,
            })

    payload = {
        "success": True,
        "data": {
            "revenue_this_month": round(revenue_this_month, 2),
            "revenue_last_month": round(revenue_last_month, 2),
            "revenue_change_percent": revenue_change,
            "expenses_this_month": round(expenses_this_month, 2),
            "expenses_last_month": round(expenses_last_month, 2),
            "net_profit": round(net_profit, 2),
            "net_profit_margin": net_margin,
            "outstanding_invoices": round(outstanding_amount, 2),
            "outstanding_balance": round(outstanding_amount, 2),
            "outstanding_count": outstanding_count,
            "inventory_value": round(inventory_value, 2),
            "stock_value": round(inventory_value, 2),
            "low_stock_count": len(low_stock_alerts),
            "vat_collected_this_month": round(vat_this_month, 2),
            "net_vat_payable": round(net_vat_payable, 2),
            "estimated_cit_quarterly": round(cit_estimate, 2),
            "revenue_trend": revenue_trend,
            "expense_breakdown": expense_breakdown,
            "top_selling_products": top_products,
            "cash_flow": cash_flow,
            "monthly_cash_flow": cash_flow,
            "recent_invoices": recent_invoices,
            "recent_expenses": recent_expenses,
            "low_stock_alerts": low_stock_alerts,
        },
    }
    await cache_set_json(cache_key, payload, settings.DASHBOARD_CACHE_SECONDS)
    return payload
