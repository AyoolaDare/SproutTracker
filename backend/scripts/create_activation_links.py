import argparse
import hashlib
import os
import secrets
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import create_engine, text

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create password setup links for migrated users.")
    parser.add_argument("--frontend-url", required=True, help="Flutter/Vercel frontend URL.")
    parser.add_argument("--email", default="", help="Create a link for one email only.")
    parser.add_argument("--expires-hours", type=int, default=72)
    parser.add_argument("--send-email", action="store_true", help="Email each setup link using configured SMTP.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    # This CLI can target production DB/SMTP from a local machine, but it is not
    # serving browser traffic. Avoid blocking on web runtime host/CORS checks.
    os.environ["ENVIRONMENT"] = "development"
    os.environ["FRONTEND_URL"] = args.frontend_url.rstrip("/")

    from app.config import get_settings
    from app.services.email import send_password_setup_email

    settings = get_settings()
    engine = create_engine(settings.sync_database_url, future=True, pool_pre_ping=True)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=args.expires_hours)
    frontend_url = args.frontend_url.rstrip("/")

    query = """
        SELECT id, email
        FROM users
        WHERE firebase_uid IS NOT NULL
          AND password_set_at IS NULL
    """
    params = {}
    if args.email:
        query += " AND lower(email) = lower(:email)"
        params["email"] = args.email
    query += " ORDER BY email"

    with engine.begin() as conn:
        users = conn.execute(text(query), params).mappings().all()
        for user in users:
            token = secrets.token_urlsafe(48)
            setup_url = f"{frontend_url}/reset-password?token={token}"
            conn.execute(
                text(
                    """
                    UPDATE users
                    SET password_reset_token_hash = :token_hash,
                        password_reset_expires_at = :expires_at,
                        updated_at = now()
                    WHERE id = :user_id
                    """
                ),
                {
                    "token_hash": token_hash(token),
                    "expires_at": expires_at,
                    "user_id": user["id"],
                },
            )
            if args.send_email:
                send_password_setup_email(user["email"], setup_url)
                print(f"sent {user['email']}")
            else:
                print(f"{user['email']} {setup_url}")

    print(f"created_links={len(users)} expires_at={expires_at.isoformat()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
