import argparse
import hashlib
import secrets
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sqlalchemy import create_engine, text

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create password setup links for migrated users.")
    parser.add_argument("--frontend-url", required=True, help="Flutter/Vercel frontend URL.")
    parser.add_argument("--email", default="", help="Create a link for one email only.")
    parser.add_argument("--expires-hours", type=int, default=72)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
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
            print(f"{user['email']} {frontend_url}/reset-password?token={token}")

    print(f"created_links={len(users)} expires_at={expires_at.isoformat()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
