from __future__ import annotations

from html import escape

from weasyprint import HTML

from app.models.invoice import Invoice


def money(value) -> str:
    return f"NGN {float(value or 0):,.2f}"


def document_label(invoice: Invoice) -> str:
    if invoice.status.value == "QUOTATION":
        return "QUOTATION"
    if invoice.status.value == "PROFORMA":
        return "PROFORMA INVOICE"
    if invoice.payment_status.value == "PAID":
        return "RECEIPT"
    return "INVOICE"


def invoice_html(invoice: Invoice, verify_url: str) -> str:
    tenant = invoice.tenant
    customer = invoice.customer
    rows = "\n".join(
        f"""
        <tr>
          <td>{escape(item.description)}</td>
          <td class="num">{item.quantity}</td>
          <td class="num">{money(item.unit_price)}</td>
          <td class="num">{money(item.line_total)}</td>
        </tr>
        """
        for item in invoice.items
    )
    return f"""
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        @page {{ size: A4; margin: 28px; }}
        body {{ font-family: Arial, sans-serif; color: #202418; font-size: 13px; }}
        .top {{ display: flex; justify-content: space-between; gap: 28px; align-items: flex-start; }}
        .brand {{ font-size: 24px; font-weight: 800; color: #606c38; }}
        .doc {{ text-align: right; }}
        .doc h1 {{ margin: 0; font-size: 28px; letter-spacing: 1px; }}
        .muted {{ color: #667066; }}
        .box {{ border: 1px solid #d9dec9; border-radius: 8px; padding: 14px; margin-top: 22px; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 24px; }}
        th {{ background: #eef1e4; text-align: left; padding: 10px; }}
        td {{ border-bottom: 1px solid #e5e7dc; padding: 10px; vertical-align: top; }}
        .num {{ text-align: right; }}
        .totals {{ width: 300px; margin-left: auto; margin-top: 20px; }}
        .totals div {{ display: flex; justify-content: space-between; padding: 6px 0; }}
        .grand {{ border-top: 2px solid #606c38; font-weight: 800; font-size: 15px; }}
        .footer {{ display: flex; justify-content: space-between; gap: 24px; margin-top: 34px; color: #667066; }}
      </style>
    </head>
    <body>
      <div class="top">
        <div>
          <div class="brand">{escape(tenant.business_name)}</div>
          <div>{escape(tenant.address or "")}</div>
          <div>{escape(tenant.email or "")} {escape(tenant.phone or "")}</div>
          <div>{escape(tenant.website or "")}</div>
        </div>
        <div class="doc">
          <h1>{document_label(invoice)}</h1>
          <div>{escape(invoice.invoice_number)}</div>
          <div class="muted">Issued {invoice.invoice_date.isoformat()}</div>
          <div class="muted">Due {invoice.due_date.isoformat()}</div>
        </div>
      </div>

      <div class="box">
        <strong>Billed to</strong><br>
        {escape(customer.name if customer else "Customer")}<br>
        {escape(customer.company if customer and customer.company else "")}<br>
        {escape(customer.email if customer and customer.email else "")}<br>
        {escape(customer.phone if customer and customer.phone else "")}<br>
        {escape(customer.address if customer and customer.address else "")}
      </div>

      <table>
        <thead>
          <tr><th>Item</th><th class="num">Qty</th><th class="num">Unit price</th><th class="num">Total</th></tr>
        </thead>
        <tbody>{rows}</tbody>
      </table>

      <div class="totals">
        <div><span>Subtotal</span><span>{money(invoice.subtotal)}</span></div>
        <div><span>Discount</span><span>{money(invoice.discount_amount)}</span></div>
        <div><span>VAT</span><span>{money(invoice.vat_amount)}</span></div>
        <div><span>WHT</span><span>{money(invoice.wht_amount)}</span></div>
        <div class="grand"><span>Total</span><span>{money(invoice.total_amount)}</span></div>
        <div><span>Paid</span><span>{money(invoice.paid_amount)}</span></div>
        <div><span>Balance</span><span>{money(invoice.outstanding_amount)}</span></div>
      </div>

      <div class="footer">
        <div>
          <strong>Bank details</strong><br>
          {escape(tenant.bank_name or "")}<br>
          {escape(tenant.bank_account_name or "")}<br>
          {escape(tenant.bank_account_number or "")}
        </div>
        <div>
          <strong>Verify document</strong><br>
          {escape(verify_url)}
        </div>
      </div>
      <p class="muted">{escape(invoice.notes or "")}</p>
      <p class="muted">{escape(invoice.terms or "")}</p>
    </body>
    </html>
    """


def render_invoice_pdf(invoice: Invoice, verify_url: str) -> bytes:
    return HTML(string=invoice_html(invoice, verify_url)).write_pdf()
