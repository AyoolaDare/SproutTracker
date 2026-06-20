import argparse
import asyncio
import os
import sys
from pathlib import Path

from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check whether an auth email exists and can receive account emails."
    )
    parser.add_argument("--email", required=True, help="User email address to inspect.")
    return parser.parse_args()


async def main() -> int:
    os.environ.setdefault("ENVIRONMENT", "development")

    from app.database import AsyncSessionLocal
    from app.models.user import User

    args = parse_args()
    email = args.email.strip().lower()

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()

    if not user:
        print(f"email={email}")
        print("exists=false")
        print("mail_sent_by_reset_or_resend=false")
        print("reason=No user row exists for this email. Forgot password will still show a generic success message.")
        return 0

    print(f"email={email}")
    print("exists=true")
    print(f"user_id={user.id}")
    print(f"tenant_id={user.tenant_id}")
    print(f"is_active={user.is_active}")
    print(f"email_verified={user.email_verified_at is not None}")
    print(f"password_set={user.password_set_at is not None}")
    print(f"has_pending_reset={user.password_reset_token_hash is not None}")
    print(f"has_pending_verification={user.email_verification_token_hash is not None}")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
