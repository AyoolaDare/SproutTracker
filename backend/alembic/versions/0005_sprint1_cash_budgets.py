"""Sprint 1 cash position and expense budgets

Revision ID: 0005_sprint1_cash_budgets
Revises: 0004_invoice_document_statuses
Create Date: 2026-06-21
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0005_sprint1_cash_budgets"
down_revision: Union[str, None] = "0004_invoice_document_statuses"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "cash_positions",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("tenant_id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=True),
        sa.Column("cash_on_hand", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("bank_balance", sa.Numeric(15, 2), nullable=False, server_default="0"),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_cash_positions_tenant_id", "cash_positions", ["tenant_id"])
    op.create_index("ix_cash_positions_recorded_at", "cash_positions", ["recorded_at"])

    op.create_table(
        "expense_budgets",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("tenant_id", sa.String(length=36), nullable=False),
        sa.Column("category", sa.String(length=100), nullable=False),
        sa.Column("month", sa.Date(), nullable=False),
        sa.Column("amount", sa.Numeric(15, 2), nullable=False),
        sa.Column("alert_threshold_percent", sa.Numeric(5, 2), nullable=False, server_default="80"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["tenant_id"], ["tenants.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("tenant_id", "category", "month", name="uq_expense_budget_tenant_category_month"),
    )
    op.create_index("ix_expense_budgets_tenant_id", "expense_budgets", ["tenant_id"])


def downgrade() -> None:
    op.drop_index("ix_expense_budgets_tenant_id", table_name="expense_budgets")
    op.drop_table("expense_budgets")
    op.drop_index("ix_cash_positions_recorded_at", table_name="cash_positions")
    op.drop_index("ix_cash_positions_tenant_id", table_name="cash_positions")
    op.drop_table("cash_positions")
