"""email verification and oauth identity fields

Revision ID: 0003_email_verification_oauth
Revises: 0002_user_password_activation
Create Date: 2026-06-20
"""

from alembic import op
import sqlalchemy as sa


revision = "0003_email_verification_oauth"
down_revision = "0002_user_password_activation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("email_verified_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("email_verification_token_hash", sa.String(128), nullable=True))
    op.add_column("users", sa.Column("email_verification_expires_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("users", sa.Column("oauth_provider", sa.String(50), nullable=True))
    op.add_column("users", sa.Column("oauth_subject", sa.String(200), nullable=True))
    op.create_index("ix_users_email_verification_token_hash", "users", ["email_verification_token_hash"])
    op.create_index("ix_users_oauth_identity", "users", ["oauth_provider", "oauth_subject"], unique=True)

    # Existing imported/registered users predate email verification. Keep them usable.
    op.execute(
        """
        UPDATE users
        SET email_verified_at = COALESCE(email_verified_at, created_at, now())
        WHERE email_verified_at IS NULL
        """
    )


def downgrade() -> None:
    op.drop_index("ix_users_oauth_identity", table_name="users")
    op.drop_index("ix_users_email_verification_token_hash", table_name="users")
    op.drop_column("users", "oauth_subject")
    op.drop_column("users", "oauth_provider")
    op.drop_column("users", "email_verification_expires_at")
    op.drop_column("users", "email_verification_token_hash")
    op.drop_column("users", "email_verified_at")
