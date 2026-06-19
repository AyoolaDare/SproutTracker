from pydantic import BaseModel
from datetime import date


class DateRangeParams(BaseModel):
    start_date: date
    end_date: date


class ProfitLossReport(BaseModel):
    period_start: date
    period_end: date
    revenue: float
    vat_collected: float
    cost_of_goods_sold: float
    gross_profit: float
    gross_margin_percent: float
    operating_expenses: float
    operating_expenses_by_category: dict[str, float]
    operating_income: float
    tax_provisions: dict[str, float]
    net_profit: float
    net_margin_percent: float


class SalesReportItem(BaseModel):
    name: str
    quantity_sold: int
    revenue: float
    cogs: float
    profit: float
    margin_percent: float


class SalesReport(BaseModel):
    period_start: date
    period_end: date
    group_by: str
    items: list[SalesReportItem]
    total_revenue: float
    total_cogs: float
    total_profit: float


class VATReportTransaction(BaseModel):
    reference: str
    counterparty: str
    amount: float
    vat_amount: float
    date: date


class VATReport(BaseModel):
    period_month: int
    period_year: int
    output_vat_total_sales: float
    output_vat_collected: float
    output_transactions: list[VATReportTransaction]
    input_vat_total_purchases: float
    input_vat_paid: float
    input_transactions: list[VATReportTransaction]
    net_vat_payable: float
    filing_due_date: date


class CashFlowReport(BaseModel):
    period_start: date
    period_end: date
    cash_from_customers: float
    cash_to_suppliers: float
    operating_expenses_paid: float
    net_operating: float
    capital_expenditure: float
    net_investing: float
    net_change_in_cash: float
    monthly_breakdown: list[dict]


class InventoryValuationItem(BaseModel):
    product_id: str
    product_name: str
    sku: str
    quantity: int
    average_cost: float
    total_cost_value: float
    selling_price: float
    total_retail_value: float
    potential_margin: float


class InventoryValuationReport(BaseModel):
    as_of_date: date
    items: list[InventoryValuationItem]
    total_cost_value: float
    total_retail_value: float
    total_potential_margin: float


class DashboardMetrics(BaseModel):
    # KPIs
    revenue_this_month: float
    revenue_change_percent: float
    net_profit: float
    net_profit_margin: float
    outstanding_invoices: float
    outstanding_count: int
    inventory_value: float

    # Tax summary
    vat_collected_this_month: float
    net_vat_payable: float
    estimated_cit_quarterly: float

    # Charts data
    revenue_trend: list[dict]  # [{month, revenue}]
    expense_breakdown: list[dict]  # [{category, amount}]
    top_selling_products: list[dict]  # [{name, quantity, revenue}]
    cash_flow: list[dict]  # [{month, inflow, outflow}]

    # Tables
    recent_invoices: list[dict]
    low_stock_alerts: list[dict]
