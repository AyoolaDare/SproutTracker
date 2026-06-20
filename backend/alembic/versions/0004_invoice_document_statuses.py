"""invoice quotation and proforma statuses

Revision ID: 0004_invoice_document_statuses
Revises: 0003_email_verification_oauth
Create Date: 2026-06-20
"""

from alembic import op


revision = "0004_invoice_document_statuses"
down_revision = "0003_email_verification_oauth"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE invoicestatus ADD VALUE IF NOT EXISTS 'QUOTATION'")
    op.execute("ALTER TYPE invoicestatus ADD VALUE IF NOT EXISTS 'PROFORMA'")


def downgrade() -> None:
    # PostgreSQL does not support dropping enum values safely without recreating
    # the type and rewriting dependent columns. Leave values in place.
    pass
