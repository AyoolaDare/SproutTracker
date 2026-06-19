"""initial Sprout Track schema

Revision ID: 0001_initial_schema
Revises:
Create Date: 2026-06-18
"""

from alembic import op
import sqlalchemy as sa


revision = "0001_initial_schema"
down_revision = None
branch_labels = None
depends_on = None


business_type = sa.Enum("RETAIL", "WHOLESALE", "SERVICE", "MIXED", name="businesstype")
accounting_basis = sa.Enum("CASH", "ACCRUAL", name="accountingbasis")
user_role = sa.Enum("OWNER", "ADMIN", "STAFF", "ACCOUNTANT", name="userrole")
movement_type = sa.Enum("PURCHASE", "SALE", "ADJUSTMENT", "RETURN", "DAMAGE", name="movementtype")
invoice_status = sa.Enum("DRAFT", "SENT", "VIEWED", "OVERDUE", "VOID", name="invoicestatus")
payment_status = sa.Enum("UNPAID", "PARTIALLY_PAID", "PAID", "OVERPAID", name="paymentstatus")
payment_method = sa.Enum("CASH", "BANK_TRANSFER", "CHEQUE", "CARD", "MOBILE_MONEY", "OTHER", name="paymentmethod")


def timestamps() -> list[sa.Column]:
    return [
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    ]


def upgrade() -> None:
    op.create_table(
        "tenants",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("firebase_user_id", sa.String(128), unique=True),
        sa.Column("business_name", sa.String(200), nullable=False),
        sa.Column("business_type", business_type, nullable=False, server_default="RETAIL"),
        sa.Column("tin", sa.String(20)),
        sa.Column("rc_number", sa.String(20)),
        sa.Column("currency", sa.String(3), nullable=False, server_default="NGN"),
        sa.Column("country", sa.String(2), nullable=False, server_default="NG"),
        sa.Column("financial_year_start", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("accounting_basis", accounting_basis, nullable=False, server_default="CASH"),
        sa.Column("inventory_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("vat_registered", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("address", sa.String(500)),
        sa.Column("phone", sa.String(20)),
        sa.Column("email", sa.String(200)),
        sa.Column("website", sa.String(200)),
        sa.Column("logo_url", sa.String(500)),
        sa.Column("bank_name", sa.String(100)),
        sa.Column("bank_account_number", sa.String(20)),
        sa.Column("bank_account_name", sa.String(200)),
        *timestamps(),
    )

    op.create_table(
        "users",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("firebase_uid", sa.String(128), unique=True),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("email", sa.String(200), nullable=False),
        sa.Column("password_hash", sa.String(200), nullable=False),
        sa.Column("full_name", sa.String(200), nullable=False),
        sa.Column("role", user_role, nullable=False, server_default="OWNER"),
        sa.Column("permissions", sa.JSON()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("mfa_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("mfa_secret", sa.String(100)),
        sa.Column("last_login_at", sa.DateTime(timezone=True)),
        sa.Column("failed_attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("locked_until", sa.DateTime(timezone=True)),
        *timestamps(),
    )
    op.create_index("ix_users_tenant_id", "users", ["tenant_id"])
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "customers",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("firestore_id", sa.String(128)),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("email", sa.String(200)),
        sa.Column("phone", sa.String(20)),
        sa.Column("address", sa.Text()),
        sa.Column("company", sa.String(200)),
        sa.Column("tin", sa.String(20)),
        sa.Column("total_revenue", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("outstanding_balance", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("total_paid", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("is_wht_applicable", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("status", sa.String(20), nullable=False, server_default="ACTIVE"),
        sa.Column("notes", sa.Text()),
        *timestamps(),
    )
    op.create_index("ix_customers_tenant_id", "customers", ["tenant_id"])
    op.create_index("uq_customers_tenant_firestore_id", "customers", ["tenant_id", "firestore_id"], unique=True)

    op.create_table(
        "products",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("firestore_id", sa.String(128)),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("sku", sa.String(50), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("category", sa.String(100)),
        sa.Column("selling_price", sa.Numeric(15, 2), nullable=False),
        sa.Column("track_inventory", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("reorder_level", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("vat_applicable", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        *timestamps(),
    )
    op.create_index("ix_products_tenant_id", "products", ["tenant_id"])
    op.create_index("ix_products_sku", "products", ["sku"])
    op.create_index("uq_products_tenant_firestore_id", "products", ["tenant_id", "firestore_id"], unique=True)
    op.create_index("uq_products_tenant_sku", "products", ["tenant_id", "sku"], unique=True)

    op.create_table(
        "tax_settings",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("vat_rate", sa.Numeric(5, 4), nullable=False, server_default="0.075"),
        sa.Column("vat_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("vat_exempt_categories", sa.JSON()),
        sa.Column("wht_rate_services", sa.Numeric(5, 4), nullable=False, server_default="0.05"),
        sa.Column("wht_rate_professional", sa.Numeric(5, 4), nullable=False, server_default="0.10"),
        sa.Column("cit_rate", sa.Numeric(5, 4), nullable=False, server_default="0.30"),
        sa.Column("is_small_company", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("small_company_cit_rate", sa.Numeric(5, 4), nullable=False, server_default="0.20"),
        sa.Column("tetfund_rate", sa.Numeric(5, 4), nullable=False, server_default="0.025"),
        *timestamps(),
    )

    op.create_table(
        "inventory_batches",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("firestore_id", sa.String(128)),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", sa.String(36), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("unit_cost", sa.Numeric(15, 2), nullable=False),
        sa.Column("initial_quantity", sa.Integer(), nullable=False),
        sa.Column("remaining_quantity", sa.Integer(), nullable=False),
        sa.Column("date_received", sa.DateTime(timezone=True), nullable=False),
        sa.Column("batch_number", sa.String(50)),
        sa.Column("supplier_ref", sa.String(200)),
        sa.Column("is_exhausted", sa.Boolean(), nullable=False, server_default=sa.false()),
        *timestamps(),
        sa.CheckConstraint("initial_quantity >= 0", name="ck_inventory_batches_initial_quantity_non_negative"),
        sa.CheckConstraint("remaining_quantity >= 0", name="ck_inventory_batches_remaining_quantity_non_negative"),
    )
    op.create_index("ix_inventory_batches_tenant_id", "inventory_batches", ["tenant_id"])
    op.create_index("ix_inventory_batches_product_id", "inventory_batches", ["product_id"])
    op.create_index("uq_inventory_batches_tenant_firestore_id", "inventory_batches", ["tenant_id", "firestore_id"], unique=True)

    op.create_table(
        "invoices",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("firestore_id", sa.String(128)),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("customer_id", sa.String(36), sa.ForeignKey("customers.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("invoice_number", sa.String(50), nullable=False),
        sa.Column("invoice_date", sa.Date(), nullable=False),
        sa.Column("due_date", sa.Date(), nullable=False),
        sa.Column("subtotal", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("discount_amount", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("discount_type", sa.String(10)),
        sa.Column("discount_value", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("vat_amount", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("wht_amount", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("total_amount", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("total_cost", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("gross_profit", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("paid_amount", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("outstanding_amount", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("status", invoice_status, nullable=False, server_default="DRAFT"),
        sa.Column("payment_status", payment_status, nullable=False, server_default="UNPAID"),
        sa.Column("wht_applied", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("wht_certificate_number", sa.String(50)),
        sa.Column("notes", sa.Text()),
        sa.Column("terms", sa.Text()),
        sa.Column("pdf_url", sa.String(500)),
        sa.Column("public_share_url", sa.String(500)),
        *timestamps(),
    )
    op.create_index("ix_invoices_tenant_id", "invoices", ["tenant_id"])
    op.create_index("ix_invoices_customer_id", "invoices", ["customer_id"])
    op.create_index("uq_invoices_tenant_firestore_id", "invoices", ["tenant_id", "firestore_id"], unique=True)
    op.create_index("ix_invoices_invoice_number", "invoices", ["invoice_number"], unique=True)
    op.create_index("ix_invoices_tenant_date", "invoices", ["tenant_id", "invoice_date"])

    op.create_table(
        "invoice_items",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("invoice_id", sa.String(36), sa.ForeignKey("invoices.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", sa.String(36), sa.ForeignKey("products.id", ondelete="SET NULL")),
        sa.Column("description", sa.String(500), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("unit_price", sa.Numeric(15, 2), nullable=False),
        sa.Column("line_total", sa.Numeric(15, 2), nullable=False),
        sa.Column("unit_cost", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("total_cost", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("line_profit", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("vat_rate", sa.Numeric(5, 4), nullable=False, server_default="0"),
        sa.Column("vat_amount", sa.Numeric(15, 2), nullable=False, server_default="0"),
        *timestamps(),
        sa.CheckConstraint("quantity > 0", name="ck_invoice_items_quantity_positive"),
    )
    op.create_index("ix_invoice_items_invoice_id", "invoice_items", ["invoice_id"])

    op.create_table(
        "batch_allocations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("invoice_item_id", sa.String(36), sa.ForeignKey("invoice_items.id", ondelete="CASCADE"), nullable=False),
        sa.Column("batch_id", sa.String(36), sa.ForeignKey("inventory_batches.id", ondelete="CASCADE"), nullable=False),
        sa.Column("quantity_allocated", sa.Integer(), nullable=False),
        sa.Column("unit_cost", sa.Numeric(15, 2), nullable=False),
        sa.Column("total_cost", sa.Numeric(15, 2), nullable=False),
        *timestamps(),
    )
    op.create_index("ix_batch_allocations_invoice_item_id", "batch_allocations", ["invoice_item_id"])
    op.create_index("ix_batch_allocations_batch_id", "batch_allocations", ["batch_id"])

    op.create_table(
        "stock_movements",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("firestore_id", sa.String(128)),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", sa.String(36), sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("movement_type", movement_type, nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("unit_value", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("total_value", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("reference_type", sa.String(50)),
        sa.Column("reference_id", sa.String(36)),
        sa.Column("user_id", sa.String(36)),
        sa.Column("notes", sa.Text()),
        *timestamps(),
    )
    op.create_index("ix_stock_movements_tenant_id", "stock_movements", ["tenant_id"])
    op.create_index("ix_stock_movements_product_id", "stock_movements", ["product_id"])
    op.create_index("uq_stock_movements_tenant_firestore_id", "stock_movements", ["tenant_id", "firestore_id"], unique=True)
    op.create_index("ix_stock_movements_reference", "stock_movements", ["reference_type", "reference_id"])

    op.create_table(
        "payments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("invoice_id", sa.String(36), sa.ForeignKey("invoices.id", ondelete="CASCADE"), nullable=False),
        sa.Column("amount", sa.Numeric(15, 2), nullable=False),
        sa.Column("payment_date", sa.Date(), nullable=False),
        sa.Column("payment_method", payment_method, nullable=False),
        sa.Column("reference_number", sa.String(100)),
        sa.Column("notes", sa.Text()),
        *timestamps(),
    )
    op.create_index("ix_payments_invoice_id", "payments", ["invoice_id"])

    op.create_table(
        "expenses",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("firestore_id", sa.String(128)),
        sa.Column("tenant_id", sa.String(36), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("description", sa.String(500), nullable=False),
        sa.Column("amount", sa.Numeric(15, 2), nullable=False),
        sa.Column("category", sa.String(100), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("vendor", sa.String(200)),
        sa.Column("reference_number", sa.String(100)),
        sa.Column("receipt_url", sa.String(500)),
        sa.Column("is_tax_deductible", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_capital_expenditure", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("notes", sa.Text()),
        sa.Column("vat_amount", sa.Numeric(15, 2), nullable=False, server_default="0"),
        *timestamps(),
    )
    op.create_index("ix_expenses_tenant_id", "expenses", ["tenant_id"])
    op.create_index("uq_expenses_tenant_firestore_id", "expenses", ["tenant_id", "firestore_id"], unique=True)
    op.create_index("ix_expenses_tenant_date", "expenses", ["tenant_id", "date"])

    op.create_table(
        "audit_logs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("tenant_id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(36)),
        sa.Column("action", sa.String(50), nullable=False),
        sa.Column("entity_type", sa.String(50), nullable=False),
        sa.Column("entity_id", sa.String(36), nullable=False),
        sa.Column("old_values", sa.JSON()),
        sa.Column("new_values", sa.JSON()),
        sa.Column("ip_address", sa.String(45)),
        sa.Column("user_agent", sa.Text()),
        *timestamps(),
    )
    op.create_index("ix_audit_logs_tenant_id", "audit_logs", ["tenant_id"])
    op.create_index("ix_audit_logs_entity", "audit_logs", ["entity_type", "entity_id"])


def downgrade() -> None:
    for table in (
        "audit_logs",
        "expenses",
        "payments",
        "stock_movements",
        "batch_allocations",
        "invoice_items",
        "invoices",
        "inventory_batches",
        "tax_settings",
        "products",
        "customers",
        "users",
        "tenants",
    ):
        op.drop_table(table)

    payment_method.drop(op.get_bind(), checkfirst=True)
    payment_status.drop(op.get_bind(), checkfirst=True)
    invoice_status.drop(op.get_bind(), checkfirst=True)
    movement_type.drop(op.get_bind(), checkfirst=True)
    user_role.drop(op.get_bind(), checkfirst=True)
    accounting_basis.drop(op.get_bind(), checkfirst=True)
    business_type.drop(op.get_bind(), checkfirst=True)
