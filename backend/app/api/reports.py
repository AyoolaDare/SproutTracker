from datetime import date, timedelta
from calendar import monthrange
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, extract
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models.user import User
from app.models.invoice import Invoice, InvoiceItem, InvoiceStatus, PaymentStatus
from app.models.expense import Expense
from app.models.product import Product
from app.models.inventory import InventoryBatch
from app.models.tax import TaxSettings
from app.middleware.auth import get_current_user
from app.services.tax import calculate_cit

router = APIRouter(prefix="/api/reports", tags=["Reports"])


@router.get("/profit-loss")
async def profit_loss_report(
    start_date: date = Query(...),
    end_date: date = Query(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    tid = user.tenant_id

    # Revenue from finalized invoices (not DRAFT or VOID)
    inv_result = await db.execute(
        select(Invoice)
        .where(
            Invoice.tenant_id == tid,
            Invoice.status.notin_([InvoiceStatus.DRAFT, InvoiceStatus.VOID]),
            Invoice.invoice_date >= start_date,
            Invoice.invoice_date <= end_date,
        )
    )
    invoices = inv_result.scalars().all()

    revenue = sum(float(i.total_amount) for i in invoices)
    vat_collected = sum(float(i.vat_amount) for i in invoices)
    cogs = sum(float(i.total_cost) for i in invoices)
    gross_profit = revenue - cogs

    # Operating expenses
    exp_result = await db.execute(
        select(Expense).where(
            Expense.tenant_id == tid,
            Expense.date >= start_date,
            Expense.date <= end_date,
            Expense.is_capital_expenditure == False,
        )
    )
    expenses = exp_result.scalars().all()
    operating_expenses = sum(float(e.amount) for e in expenses)

    # Group by category
    expenses_by_category = {}
    for e in expenses:
        cat = e.category or "Other"
        expenses_by_category[cat] = expenses_by_category.get(cat, 0) + float(e.amount)

    operating_income = gross_profit - operating_expenses
    net_profit = operating_income

    # Tax provisions
    tax_result = await db.execute(
        select(TaxSettings).where(TaxSettings.tenant_id == tid)
    )
    tax_settings = tax_result.scalar_one_or_none()
    tax_provisions = {}
    if tax_settings:
        tax_provisions["vat_collected"] = round(vat_collected, 2)
        cit = calculate_cit(
            net_profit,
            is_small_company=tax_settings.is_small_company,
            cit_rate=float(tax_settings.cit_rate),
            small_company_cit_rate=float(tax_settings.small_company_cit_rate),
            tetfund_rate=float(tax_settings.tetfund_rate),
        )
        tax_provisions["cit"] = cit["cit"]
        tax_provisions["tetfund"] = cit["tetfund"]

    gross_margin = round((gross_profit / revenue * 100), 2) if revenue > 0 else 0
    net_margin = round((net_profit / revenue * 100), 2) if revenue > 0 else 0

    return {
        "success": True,
        "data": {
            "period_start": start_date.isoformat(),
            "period_end": end_date.isoformat(),
            "revenue": round(revenue, 2),
            "vat_collected": round(vat_collected, 2),
            "cost_of_goods_sold": round(cogs, 2),
            "gross_profit": round(gross_profit, 2),
            "gross_margin_percent": gross_margin,
            "operating_expenses": round(operating_expenses, 2),
            "operating_expenses_by_category": expenses_by_category,
            "operating_income": round(operating_income, 2),
            "tax_provisions": tax_provisions,
            "net_profit": round(net_profit, 2),
            "net_margin_percent": net_margin,
        },
    }


@router.get("/sales")
async def sales_report(
    start_date: date = Query(...),
    end_date: date = Query(...),
    group_by: str = Query("product", regex="^(product|customer|month)$"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    tid = user.tenant_id

    inv_result = await db.execute(
        select(Invoice)
        .options(selectinload(Invoice.items).selectinload(InvoiceItem.product),
                 selectinload(Invoice.customer))
        .where(
            Invoice.tenant_id == tid,
            Invoice.status.notin_([InvoiceStatus.DRAFT, InvoiceStatus.VOID]),
            Invoice.invoice_date >= start_date,
            Invoice.invoice_date <= end_date,
        )
    )
    invoices = inv_result.scalars().unique().all()

    if group_by == "product":
        grouped = {}
        for inv in invoices:
            for item in inv.items:
                name = item.description
                if name not in grouped:
                    grouped[name] = {"name": name, "quantity_sold": 0, "revenue": 0, "cogs": 0}
                grouped[name]["quantity_sold"] += item.quantity
                grouped[name]["revenue"] += float(item.line_total)
                grouped[name]["cogs"] += float(item.total_cost)

        items = []
        for g in grouped.values():
            profit = g["revenue"] - g["cogs"]
            margin = round(profit / g["revenue"] * 100, 2) if g["revenue"] > 0 else 0
            items.append({**g, "profit": round(profit, 2), "margin_percent": margin})
        items.sort(key=lambda x: x["revenue"], reverse=True)

    elif group_by == "customer":
        grouped = {}
        for inv in invoices:
            name = inv.customer.name if inv.customer else "Unknown"
            if name not in grouped:
                grouped[name] = {"name": name, "quantity_sold": 0, "revenue": 0, "cogs": 0}
            grouped[name]["revenue"] += float(inv.total_amount)
            grouped[name]["cogs"] += float(inv.total_cost)
            for item in inv.items:
                grouped[name]["quantity_sold"] += item.quantity

        items = []
        for g in grouped.values():
            profit = g["revenue"] - g["cogs"]
            margin = round(profit / g["revenue"] * 100, 2) if g["revenue"] > 0 else 0
            items.append({**g, "profit": round(profit, 2), "margin_percent": margin})
        items.sort(key=lambda x: x["revenue"], reverse=True)

    else:  # month
        grouped = {}
        for inv in invoices:
            month_key = inv.invoice_date.strftime("%Y-%m")
            if month_key not in grouped:
                grouped[month_key] = {"name": month_key, "quantity_sold": 0, "revenue": 0, "cogs": 0}
            grouped[month_key]["revenue"] += float(inv.total_amount)
            grouped[month_key]["cogs"] += float(inv.total_cost)
            for item in inv.items:
                grouped[month_key]["quantity_sold"] += item.quantity

        items = []
        for g in sorted(grouped.values(), key=lambda x: x["name"]):
            profit = g["revenue"] - g["cogs"]
            margin = round(profit / g["revenue"] * 100, 2) if g["revenue"] > 0 else 0
            items.append({**g, "profit": round(profit, 2), "margin_percent": margin})

    total_revenue = sum(i["revenue"] for i in items)
    total_cogs = sum(i["cogs"] for i in items)
    total_profit = total_revenue - total_cogs

    return {
        "success": True,
        "data": {
            "period_start": start_date.isoformat(),
            "period_end": end_date.isoformat(),
            "group_by": group_by,
            "items": items,
            "total_revenue": round(total_revenue, 2),
            "total_cogs": round(total_cogs, 2),
            "total_profit": round(total_profit, 2),
        },
    }


@router.get("/vat")
async def vat_report(
    month: int = Query(..., ge=1, le=12),
    year: int = Query(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    tid = user.tenant_id
    _, last_day = monthrange(year, month)
    start = date(year, month, 1)
    end = date(year, month, last_day)

    # Output VAT (from invoices)
    inv_result = await db.execute(
        select(Invoice)
        .options(selectinload(Invoice.customer))
        .where(
            Invoice.tenant_id == tid,
            Invoice.status.notin_([InvoiceStatus.DRAFT, InvoiceStatus.VOID]),
            Invoice.invoice_date >= start,
            Invoice.invoice_date <= end,
        )
    )
    invoices = inv_result.scalars().unique().all()

    output_total_sales = sum(float(i.subtotal) for i in invoices)
    output_vat = sum(float(i.vat_amount) for i in invoices)
    output_transactions = [
        {
            "reference": i.invoice_number,
            "counterparty": i.customer.name if i.customer else "Unknown",
            "amount": float(i.subtotal),
            "vat_amount": float(i.vat_amount),
            "date": i.invoice_date.isoformat(),
        }
        for i in invoices
    ]

    # Input VAT (from expenses with VAT)
    exp_result = await db.execute(
        select(Expense).where(
            Expense.tenant_id == tid,
            Expense.date >= start,
            Expense.date <= end,
            Expense.vat_amount > 0,
        )
    )
    expenses = exp_result.scalars().all()

    input_total_purchases = sum(float(e.amount) for e in expenses)
    input_vat = sum(float(e.vat_amount) for e in expenses)
    input_transactions = [
        {
            "reference": e.reference_number or f"EXP-{e.id[:8]}",
            "counterparty": e.vendor or "Unknown",
            "amount": float(e.amount),
            "vat_amount": float(e.vat_amount),
            "date": e.date.isoformat(),
        }
        for e in expenses
    ]

    net_vat = output_vat - input_vat

    # Filing due date: 21st of following month
    if month == 12:
        filing_due = date(year + 1, 1, 21)
    else:
        filing_due = date(year, month + 1, 21)

    return {
        "success": True,
        "data": {
            "period_month": month,
            "period_year": year,
            "output_vat_total_sales": round(output_total_sales, 2),
            "output_vat_collected": round(output_vat, 2),
            "output_transactions": output_transactions,
            "input_vat_total_purchases": round(input_total_purchases, 2),
            "input_vat_paid": round(input_vat, 2),
            "input_transactions": input_transactions,
            "net_vat_payable": round(net_vat, 2),
            "filing_due_date": filing_due.isoformat(),
        },
    }


@router.get("/cash-flow")
async def cash_flow_report(
    start_date: date = Query(...),
    end_date: date = Query(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    tid = user.tenant_id

    # Cash from customers (payments received)
    from app.models.invoice import Payment
    pay_result = await db.execute(
        select(Payment)
        .join(Invoice)
        .where(
            Invoice.tenant_id == tid,
            Payment.payment_date >= start_date,
            Payment.payment_date <= end_date,
        )
    )
    payments = pay_result.scalars().all()
    cash_from_customers = sum(float(p.amount) for p in payments)

    # Operating expenses
    exp_result = await db.execute(
        select(Expense).where(
            Expense.tenant_id == tid,
            Expense.date >= start_date,
            Expense.date <= end_date,
        )
    )
    expenses = exp_result.scalars().all()
    operating_expenses_paid = sum(float(e.amount) for e in expenses if not e.is_capital_expenditure)
    capital_expenditure = sum(float(e.amount) for e in expenses if e.is_capital_expenditure)

    net_operating = cash_from_customers - operating_expenses_paid
    net_investing = -capital_expenditure
    net_change = net_operating + net_investing

    # Monthly breakdown
    monthly = {}
    for p in payments:
        month_key = p.payment_date.strftime("%Y-%m")
        if month_key not in monthly:
            monthly[month_key] = {"month": month_key, "inflow": 0, "outflow": 0}
        monthly[month_key]["inflow"] += float(p.amount)

    for e in expenses:
        month_key = e.date.strftime("%Y-%m")
        if month_key not in monthly:
            monthly[month_key] = {"month": month_key, "inflow": 0, "outflow": 0}
        monthly[month_key]["outflow"] += float(e.amount)

    breakdown = sorted(monthly.values(), key=lambda x: x["month"])

    return {
        "success": True,
        "data": {
            "period_start": start_date.isoformat(),
            "period_end": end_date.isoformat(),
            "cash_from_customers": round(cash_from_customers, 2),
            "operating_expenses_paid": round(operating_expenses_paid, 2),
            "net_operating": round(net_operating, 2),
            "capital_expenditure": round(capital_expenditure, 2),
            "net_investing": round(net_investing, 2),
            "net_change_in_cash": round(net_change, 2),
            "monthly_breakdown": breakdown,
        },
    }
