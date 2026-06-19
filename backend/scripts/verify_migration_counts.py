import sys
from pathlib import Path

from sqlalchemy import create_engine, text

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings


TABLES = [
    "tenants",
    "users",
    "customers",
    "products",
    "inventory_batches",
    "stock_movements",
    "invoices",
    "invoice_items",
    "payments",
    "expenses",
]


def main() -> int:
    settings = get_settings()
    engine = create_engine(settings.sync_database_url, future=True, pool_pre_ping=True)
    try:
        with engine.connect() as conn:
            for table in TABLES:
                count = conn.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar_one()
                print(f"{table}: {count}")
    finally:
        engine.dispose()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
