"""
Nigerian Tax Calculation Engine.

Covers:
- VAT (Value Added Tax) - 7.5%
- WHT (Withholding Tax) - 5% services, 10% professional
- CIT (Company Income Tax) - 30% (20% small companies)
- TETFund (Tertiary Education Tax) - 2.5%
- PIT (Personal Income Tax) - progressive brackets
"""


def calculate_vat(amount: float, vat_rate: float = 0.075, is_exempt: bool = False) -> float:
    """Calculate VAT on an amount. Returns 0 if exempt."""
    if is_exempt:
        return 0.0
    return round(amount * vat_rate, 2)


def calculate_wht(
    amount: float,
    is_applicable: bool = False,
    service_type: str = "services",
    wht_rate_services: float = 0.05,
    wht_rate_professional: float = 0.10,
) -> float:
    """Calculate Withholding Tax. Only applies if customer is WHT-applicable."""
    if not is_applicable:
        return 0.0
    rate = wht_rate_professional if service_type == "professional" else wht_rate_services
    return round(amount * rate, 2)


def calculate_cit(
    quarterly_profit: float,
    is_small_company: bool = True,
    cit_rate: float = 0.30,
    small_company_cit_rate: float = 0.20,
    tetfund_rate: float = 0.025,
) -> dict:
    """
    Estimate Company Income Tax for a quarter.

    Small company: turnover < ₦25M, rate = 20%
    Medium/large: rate = 30%
    TETFund: 2.5% of assessable profit
    """
    if quarterly_profit <= 0:
        return {"cit": 0, "tetfund": 0, "total": 0}

    rate = small_company_cit_rate if is_small_company else cit_rate
    cit = round(quarterly_profit * rate, 2)
    tetfund = round(quarterly_profit * tetfund_rate, 2)

    return {
        "cit": cit,
        "tetfund": tetfund,
        "total": round(cit + tetfund, 2),
        "effective_rate": round((cit + tetfund) / quarterly_profit * 100, 2),
    }


def calculate_pit(gross_income: float) -> dict:
    """
    Calculate Nigerian Personal Income Tax.

    Step 1: Consolidated Relief Allowance (CRA)
      - 20% of gross income
      - Higher of ₦200,000 or 1% of gross income
    Step 2: Taxable income = gross - CRA
    Step 3: Progressive tax brackets
    """
    if gross_income <= 0:
        return {
            "gross_income": 0,
            "consolidated_relief": 0,
            "taxable_income": 0,
            "total_tax": 0,
            "effective_rate": 0,
            "breakdown": [],
        }

    # CRA calculation
    twenty_percent = gross_income * 0.20
    one_percent_or_200k = max(200_000, gross_income * 0.01)
    cra = twenty_percent + one_percent_or_200k

    taxable_income = max(0, gross_income - cra)

    # Progressive tax brackets
    brackets = [
        (300_000, 0.07),
        (300_000, 0.11),
        (500_000, 0.15),
        (500_000, 0.19),
        (1_600_000, 0.21),
        (float("inf"), 0.24),
    ]

    remaining = taxable_income
    total_tax = 0
    breakdown = []

    for bracket_amount, rate in brackets:
        if remaining <= 0:
            break
        taxable_in_bracket = min(remaining, bracket_amount)
        tax_in_bracket = round(taxable_in_bracket * rate, 2)
        breakdown.append({
            "bracket": f"₦{bracket_amount:,.0f}" if bracket_amount != float("inf") else "Above ₦3,200,000",
            "rate": f"{rate * 100:.0f}%",
            "taxable_amount": round(taxable_in_bracket, 2),
            "tax": tax_in_bracket,
        })
        total_tax += tax_in_bracket
        remaining -= taxable_in_bracket

    effective_rate = round((total_tax / gross_income * 100), 2) if gross_income > 0 else 0

    return {
        "gross_income": round(gross_income, 2),
        "consolidated_relief": round(cra, 2),
        "taxable_income": round(taxable_income, 2),
        "total_tax": round(total_tax, 2),
        "effective_rate": effective_rate,
        "breakdown": breakdown,
    }


def calculate_invoice_taxes(
    subtotal: float,
    discount_amount: float = 0,
    apply_vat: bool = True,
    vat_rate: float = 0.075,
    apply_wht: bool = False,
    wht_rate: float = 0.05,
    vat_exempt_items_total: float = 0,
) -> dict:
    """
    Calculate all taxes for an invoice.

    Returns breakdown of VAT, WHT, and final total.
    """
    amount_after_discount = subtotal - discount_amount

    # VAT only on non-exempt items
    vatable_amount = amount_after_discount - vat_exempt_items_total
    vat_amount = calculate_vat(vatable_amount, vat_rate) if apply_vat else 0

    total_before_wht = amount_after_discount + vat_amount

    # WHT is deducted from total
    wht_amount = round(amount_after_discount * wht_rate, 2) if apply_wht else 0

    net_payable = total_before_wht - wht_amount

    return {
        "subtotal": round(subtotal, 2),
        "discount_amount": round(discount_amount, 2),
        "amount_after_discount": round(amount_after_discount, 2),
        "vatable_amount": round(vatable_amount, 2),
        "vat_amount": round(vat_amount, 2),
        "wht_amount": round(wht_amount, 2),
        "total_amount": round(total_before_wht, 2),
        "net_payable": round(net_payable, 2),
    }
