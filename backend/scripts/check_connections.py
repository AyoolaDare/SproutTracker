import asyncio
import re
import sys
from pathlib import Path

from redis.asyncio import Redis
from sqlalchemy import create_engine, text

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings


def safe_error(exc: Exception) -> str:
    message = str(exc).replace("\n", " ")
    message = re.sub(r"://([^:@/]+):([^@/]+)@", r"://\1:***@", message)
    message = re.sub(r"(password=)[^ )]+", r"\1***", message, flags=re.IGNORECASE)
    return message[:500]


async def check_redis(url: str) -> bool:
    client = Redis.from_url(
        url,
        encoding="utf-8",
        decode_responses=True,
        socket_connect_timeout=10,
        socket_timeout=10,
    )
    try:
        return bool(await client.ping())
    finally:
        await client.aclose()


def check_database(url: str) -> bool:
    engine = create_engine(url, future=True, pool_pre_ping=True)
    try:
        with engine.connect() as conn:
            return conn.execute(text("SELECT 1")).scalar_one() == 1
    finally:
        engine.dispose()


async def main() -> int:
    settings = get_settings()
    results = {
        "database": False,
        "redis": False,
        "supabase_url": bool(settings.SUPABASE_URL and "REPLACE_" not in settings.SUPABASE_URL),
        "supabase_service_key": bool(
            settings.SUPABASE_SERVICE_ROLE_KEY and "REPLACE_" not in settings.SUPABASE_SERVICE_ROLE_KEY
        ),
    }

    try:
        results["database"] = check_database(settings.sync_database_url)
    except Exception as exc:
        print(f"database: failed ({type(exc).__name__}) {safe_error(exc)}")

    try:
        results["redis"] = await check_redis(settings.REDIS_URL)
    except Exception as exc:
        print(f"redis: failed ({type(exc).__name__}) {safe_error(exc)}")

    for name, ok in results.items():
        print(f"{name}: {'ok' if ok else 'not ready'}")

    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
