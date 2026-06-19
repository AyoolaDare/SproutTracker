"""Migrate Sprout Track Firestore data into Supabase/PostgreSQL.

Reads the legacy shape:
  users/{firebaseUid}/profile/business
  users/{firebaseUid}/customers
  users/{firebaseUid}/inventory
  users/{firebaseUid}/inventoryHistory
  users/{firebaseUid}/invoices
  users/{firebaseUid}/expenses

Run from backend/:
  python scripts/migrate_firestore_to_postgres.py \
    --service-account ../bizbalance-o2v9w-firebase-adminsdk-fbsvc-d8e0f26993.json \
    --dry-run

Then run without --dry-run after reviewing counts.
"""

from __future__ import annotations

import argparse
import logging
import math
import os
import secrets
import sys
import uuid
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import auth, credentials, firestore
from google.cloud.firestore_v1 import DocumentReference
from passlib.context import CryptContext
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Connection, Engine

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import get_settings  # noqa: E402


logger = logging.getLogger("firestore_migration")
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


@dataclass
class Counters:
    tenants: int = 0
    users: int = 0
    customers: int = 0
    products: int = 0
    inventory_batches: int = 0
    stock_movements: int = 0
    invoices: int = 0
    invoice_items: int = 0
    payments: int = 0
    expenses: int = 0
    skipped: int = 0
    errors: list[str] = field(default_factory=list)


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def new_id() -> str:
    return str(uuid.uuid4())


def as_decimal(value: Any, default: str = "0") -> Decimal:
    if value is None or value == "":
        return Decimal(default)
    try:
        if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
            return Decimal(default)
        return Decimal(str(value))
    except Exception:
        return Decimal(default)


def as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except Exception:
        return default


def as_bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    return bool(value)


def as_date(value: Any, default: date | None = None) -> date:
    dt = as_datetime(value)
    if dt:
        return dt.date()
    return default or now_utc().date()


def as_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if hasattr(value, "to_datetime"):
        return value.to_datetime()
    if hasattr(value, "toDate"):
        return value.toDate()
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    if isinstance(value, date):
        return datetime(value.year, value.month, value.day, tzinfo=timezone.utc)
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value / 1000 if value > 10_000_000_000 else value, timezone.utc)
    if isinstance(value, str):
        try:
            clean = value.replace("Z", "+00:00")
            return datetime.fromisoformat(clean)
        except ValueError:
            return None
    return None


def clean_str(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value).strip()


def money(value: Any) -> Decimal:
    return as_decimal(value).quantize(Decimal("0.01"))


def map_invoice_status(status: str | None) -> str:
    normalized = clean_str(status, "Pending").lower()
    if normalized == "overdue":
        return "OVERDUE"
    if normalized == "void":
        return "VOID"
    return "SENT"


def map_payment_status(status: str | None, amount: Decimal, paid: Decimal) -> str:
    normalized = clean_str(status).lower()
    if normalized == "paid" or (amount > 0 and paid >= amount):
        return "PAID"
    if paid > 0:
        return "PARTIALLY_PAID"
    return "UNPAID"


def map_payment_method(method: str | None) -> str:
    normalized = clean_str(method).lower().replace(" ", "_")
    return {
        "cash": "CASH",
        "transfer": "BANK_TRANSFER",
        "bank_transfer": "BANK_TRANSFER",
        "credit": "OTHER",
        "card": "CARD",
        "cheque": "CHEQUE",
        "mobile_money": "MOBILE_MONEY",
    }.get(normalized, "OTHER")


def map_movement_type(value: str | None) -> str:
    normalized = clean_str(value).lower()
    if normalized in {"sale", "sold"}:
        return "SALE"
    if normalized in {"adjustment", "adjusted"}:
        return "ADJUSTMENT"
    if normalized in {"goods return", "return", "refund"}:
        return "RETURN"
    if normalized in {"deleted", "damage"}:
        return "DAMAGE"
    return "ADJUSTMENT"


def upsert_returning_id(
    conn: Connection,
    table: str,
    values: dict[str, Any],
    conflict: str,
    update_columns: list[str],
) -> str:
    columns = list(values.keys())
    assignments = ", ".join(f"{col} = EXCLUDED.{col}" for col in update_columns)
    sql = text(
        f"""
        INSERT INTO {table} ({", ".join(columns)})
        VALUES ({", ".join(f":{col}" for col in columns)})
        ON CONFLICT {conflict}
        DO UPDATE SET {assignments}
        RETURNING id
        """
    )
    return str(conn.execute(sql, values).scalar_one())


def insert_do_nothing(
    conn: Connection,
    table: str,
    values: dict[str, Any],
    conflict: str,
) -> bool:
    columns = list(values.keys())
    sql = text(
        f"""
        INSERT INTO {table} ({", ".join(columns)})
        VALUES ({", ".join(f":{col}" for col in columns)})
        ON CONFLICT {conflict} DO NOTHING
        RETURNING id
        """
    )
    return conn.execute(sql, values).scalar_one_or_none() is not None


def get_subcollection(user_ref: DocumentReference, name: str) -> list[Any]:
    return list(user_ref.collection(name).stream())


def get_profile(user_ref: DocumentReference) -> dict[str, Any]:
    snap = user_ref.collection("profile").document("business").get()
    return snap.to_dict() or {}


def get_auth_user(firebase_uid: str):
    try:
        return auth.get_user(firebase_uid)
    except Exception:
        return None


def create_tenant_and_owner(
    conn: Connection,
    firebase_uid: str,
    profile: dict[str, Any],
    counters: Counters,
) -> tuple[str, str]:
    user_record = get_auth_user(firebase_uid)
    email = user_record.email if user_record and user_record.email else f"{firebase_uid}@legacy.local"
    full_name = user_record.display_name if user_record and user_record.display_name else clean_str(profile.get("ownerName"), "Legacy Owner")
    business_name = clean_str(
        profile.get("businessName") or profile.get("business_name"),
        f"Imported Business {firebase_uid[:6]}",
    )
    tenant_id = upsert_returning_id(
        conn,
        "tenants",
        {
            "id": new_id(),
            "firebase_user_id": firebase_uid,
            "business_name": business_name,
            "business_type": "RETAIL",
            "tin": profile.get("tin"),
            "rc_number": profile.get("rcNumber") or profile.get("rc_number"),
            "currency": clean_str(profile.get("currency"), "NGN")[:3],
            "country": clean_str(profile.get("country"), "NG")[:2],
            "financial_year_start": as_int(profile.get("financialYearStart"), 1),
            "accounting_basis": "CASH",
            "inventory_enabled": True,
            "vat_registered": as_bool(profile.get("vatRegistered"), False),
            "address": profile.get("address"),
            "phone": profile.get("phone"),
            "email": profile.get("email") or email,
            "website": profile.get("website"),
            "logo_url": profile.get("logoUrl") or profile.get("logo"),
            "bank_name": profile.get("bankName"),
            "bank_account_number": profile.get("bankAccountNumber"),
            "bank_account_name": profile.get("bankAccountName"),
            "created_at": now_utc(),
            "updated_at": now_utc(),
        },
        "(firebase_user_id)",
        [
            "business_name",
            "tin",
            "rc_number",
            "currency",
            "country",
            "address",
            "phone",
            "email",
            "website",
            "logo_url",
            "bank_name",
            "bank_account_number",
            "bank_account_name",
            "updated_at",
        ],
    )
    counters.tenants += 1

    password_hash = pwd_context.hash(secrets.token_urlsafe(32))
    user_id = upsert_returning_id(
        conn,
        "users",
        {
            "id": new_id(),
            "firebase_uid": firebase_uid,
            "tenant_id": tenant_id,
            "email": email,
            "password_hash": password_hash,
            "password_set_at": None,
            "password_reset_token_hash": None,
            "password_reset_expires_at": None,
            "full_name": full_name,
            "role": "OWNER",
            "permissions": None,
            "is_active": not bool(user_record.disabled) if user_record else True,
            "mfa_enabled": False,
            "mfa_secret": None,
            "last_login_at": None,
            "failed_attempts": 0,
            "locked_until": None,
            "created_at": now_utc(),
            "updated_at": now_utc(),
        },
        "(firebase_uid)",
        ["tenant_id", "email", "full_name", "is_active", "updated_at"],
    )
    counters.users += 1

    insert_do_nothing(
        conn,
        "tax_settings",
        {
            "id": new_id(),
            "tenant_id": tenant_id,
            "vat_rate": as_decimal(profile.get("vatRate"), "0.075"),
            "vat_enabled": as_bool(profile.get("vatEnabled"), True),
            "vat_exempt_categories": None,
            "wht_rate_services": Decimal("0.05"),
            "wht_rate_professional": Decimal("0.10"),
            "cit_rate": Decimal("0.30"),
            "is_small_company": True,
            "small_company_cit_rate": Decimal("0.20"),
            "tetfund_rate": Decimal("0.025"),
            "created_at": now_utc(),
            "updated_at": now_utc(),
        },
        "(tenant_id)",
    )
    return tenant_id, user_id


def migrate_customers(conn: Connection, tenant_id: str, docs: list[DocumentSnapshot], counters: Counters) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for snap in docs:
        data = snap.to_dict() or {}
        customer_id = upsert_returning_id(
            conn,
            "customers",
            {
                "id": new_id(),
                "firestore_id": snap.id,
                "tenant_id": tenant_id,
                "name": clean_str(data.get("name"), "Unnamed Customer"),
                "email": data.get("email"),
                "phone": data.get("phone"),
                "address": data.get("address"),
                "company": data.get("company"),
                "tin": data.get("tin"),
                "total_revenue": money(data.get("totalSpent")),
                "outstanding_balance": money(data.get("amountOwed")),
                "total_paid": money(data.get("amountPaid")),
                "is_wht_applicable": False,
                "status": clean_str(data.get("status"), "ACTIVE").upper(),
                "notes": data.get("notes"),
                "created_at": as_datetime(data.get("createdAt")) or now_utc(),
                "updated_at": now_utc(),
            },
            "(tenant_id, firestore_id)",
            [
                "name",
                "email",
                "phone",
                "address",
                "company",
                "tin",
                "total_revenue",
                "outstanding_balance",
                "total_paid",
                "status",
                "notes",
                "updated_at",
            ],
        )
        mapping[snap.id] = customer_id
        counters.customers += 1
    return mapping


def migrate_inventory(conn: Connection, tenant_id: str, docs: list[DocumentSnapshot], counters: Counters) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for snap in docs:
        data = snap.to_dict() or {}
        qty = max(as_int(data.get("quantity")), 0)
        unit_cost = money(data.get("unitCost"))
        product_id = upsert_returning_id(
            conn,
            "products",
            {
                "id": new_id(),
                "firestore_id": snap.id,
                "tenant_id": tenant_id,
                "name": clean_str(data.get("name"), "Unnamed Product"),
                "sku": clean_str(data.get("sku"), f"LEGACY-{snap.id[:8]}")[:50],
                "description": data.get("description"),
                "category": data.get("category"),
                "selling_price": money(data.get("sellingPrice") or data.get("unitPrice") or data.get("unitCost")),
                "track_inventory": True,
                "reorder_level": as_int(data.get("reorderLevel")),
                "vat_applicable": True,
                "is_active": True,
                "created_at": as_datetime(data.get("createdAt")) or now_utc(),
                "updated_at": now_utc(),
            },
            "(tenant_id, firestore_id)",
            [
                "name",
                "sku",
                "description",
                "category",
                "selling_price",
                "reorder_level",
                "updated_at",
            ],
        )
        mapping[snap.id] = product_id
        counters.products += 1

        if qty > 0:
            created = insert_do_nothing(
                conn,
                "inventory_batches",
                {
                    "id": new_id(),
                    "firestore_id": f"{snap.id}:opening",
                    "tenant_id": tenant_id,
                    "product_id": product_id,
                    "unit_cost": unit_cost,
                    "initial_quantity": qty,
                    "remaining_quantity": qty,
                    "date_received": as_datetime(data.get("createdAt")) or now_utc(),
                    "batch_number": f"OPENING-{snap.id[:8]}",
                    "supplier_ref": data.get("supplier"),
                    "is_exhausted": False,
                    "created_at": as_datetime(data.get("createdAt")) or now_utc(),
                    "updated_at": now_utc(),
                },
                "(tenant_id, firestore_id)",
            )
            if created:
                counters.inventory_batches += 1
    return mapping


def migrate_history(
    conn: Connection,
    tenant_id: str,
    docs: list[DocumentSnapshot],
    product_map: dict[str, str],
    user_id: str,
    counters: Counters,
) -> None:
    for snap in docs:
        data = snap.to_dict() or {}
        product_id = product_map.get(clean_str(data.get("itemId")))
        if not product_id:
            counters.skipped += 1
            continue
        created = insert_do_nothing(
            conn,
            "stock_movements",
            {
                "id": new_id(),
                "firestore_id": snap.id,
                "tenant_id": tenant_id,
                "product_id": product_id,
                "movement_type": map_movement_type(data.get("type")),
                "quantity": as_int(data.get("change")),
                "unit_value": money(data.get("unitValue")),
                "total_value": money(data.get("amount")),
                "reference_type": "firestore_inventory_history",
                "reference_id": snap.id,
                "user_id": user_id,
                "notes": data.get("details") or data.get("type"),
                "created_at": as_datetime(data.get("date")) or now_utc(),
                "updated_at": now_utc(),
            },
            "(tenant_id, firestore_id)",
        )
        if created:
            counters.stock_movements += 1


def migrate_invoices(
    conn: Connection,
    tenant_id: str,
    user_id: str,
    docs: list[DocumentSnapshot],
    customer_map: dict[str, str],
    product_map: dict[str, str],
    counters: Counters,
) -> None:
    fallback_customer_id: str | None = None
    for snap in docs:
        data = snap.to_dict() or {}
        customer_id = customer_map.get(clean_str(data.get("customerId")))
        if not customer_id:
            fallback_key = f"legacy-customer-{snap.id}"
            customer_id = upsert_returning_id(
                conn,
                "customers",
                {
                    "id": new_id(),
                    "firestore_id": fallback_key,
                    "tenant_id": tenant_id,
                    "name": clean_str(data.get("customerName"), "Legacy Customer"),
                    "email": None,
                    "phone": data.get("customerPhone"),
                    "address": data.get("customerAddress"),
                    "company": data.get("customerCompany"),
                    "tin": None,
                    "total_revenue": Decimal("0"),
                    "outstanding_balance": Decimal("0"),
                    "total_paid": Decimal("0"),
                    "is_wht_applicable": False,
                    "status": "ACTIVE",
                    "notes": "Created during Firestore invoice migration",
                    "created_at": now_utc(),
                    "updated_at": now_utc(),
                },
                "(tenant_id, firestore_id)",
                ["name", "phone", "address", "company", "updated_at"],
            )
            fallback_customer_id = customer_id

        amount = money(data.get("amount"))
        amount_paid = money(data.get("amountPaid"))
        vat_amount = money(data.get("vatAmount"))
        subtotal = amount - vat_amount
        outstanding = max(amount - amount_paid, Decimal("0"))
        invoice_number = clean_str(data.get("invoiceNumber"), f"LEGACY-{snap.id[:12]}")
        invoice_id = upsert_returning_id(
            conn,
            "invoices",
            {
                "id": new_id(),
                "firestore_id": snap.id,
                "tenant_id": tenant_id,
                "customer_id": customer_id,
                "user_id": user_id,
                "invoice_number": invoice_number,
                "invoice_date": as_date(data.get("issueDate")),
                "due_date": as_date(data.get("dueDate")),
                "subtotal": subtotal,
                "discount_amount": Decimal("0"),
                "discount_type": None,
                "discount_value": Decimal("0"),
                "vat_amount": vat_amount,
                "wht_amount": Decimal("0"),
                "total_amount": amount,
                "total_cost": Decimal("0"),
                "gross_profit": subtotal,
                "paid_amount": amount_paid,
                "outstanding_amount": outstanding,
                "status": map_invoice_status(data.get("status")),
                "payment_status": map_payment_status(data.get("status"), amount, amount_paid),
                "wht_applied": False,
                "wht_certificate_number": None,
                "notes": data.get("notes"),
                "terms": data.get("terms"),
                "pdf_url": data.get("pdfUrl"),
                "public_share_url": None,
                "created_at": as_datetime(data.get("createdAt")) or now_utc(),
                "updated_at": now_utc(),
            },
            "(tenant_id, firestore_id)",
            [
                "customer_id",
                "invoice_number",
                "invoice_date",
                "due_date",
                "subtotal",
                "vat_amount",
                "total_amount",
                "paid_amount",
                "outstanding_amount",
                "status",
                "payment_status",
                "notes",
                "terms",
                "pdf_url",
                "updated_at",
            ],
        )
        counters.invoices += 1

        conn.execute(text("DELETE FROM invoice_items WHERE invoice_id = :invoice_id"), {"invoice_id": invoice_id})
        for item in data.get("lineItems") or []:
            qty = as_int(item.get("quantity"), 1)
            unit_price = money(item.get("unitPrice"))
            product_id = product_map.get(clean_str(item.get("productId")))
            conn.execute(
                text(
                    """
                    INSERT INTO invoice_items (
                        id, invoice_id, product_id, description, quantity, unit_price,
                        line_total, unit_cost, total_cost, line_profit, vat_rate,
                        vat_amount, created_at, updated_at
                    )
                    VALUES (
                        :id, :invoice_id, :product_id, :description, :quantity, :unit_price,
                        :line_total, :unit_cost, :total_cost, :line_profit, :vat_rate,
                        :vat_amount, :created_at, :updated_at
                    )
                    """
                ),
                {
                    "id": new_id(),
                    "invoice_id": invoice_id,
                    "product_id": product_id,
                    "description": clean_str(item.get("name") or item.get("description"), "Legacy item"),
                    "quantity": qty,
                    "unit_price": unit_price,
                    "line_total": money(unit_price * qty),
                    "unit_cost": Decimal("0"),
                    "total_cost": Decimal("0"),
                    "line_profit": money(unit_price * qty),
                    "vat_rate": Decimal("0"),
                    "vat_amount": Decimal("0"),
                    "created_at": as_datetime(data.get("createdAt")) or now_utc(),
                    "updated_at": now_utc(),
                },
            )
            counters.invoice_items += 1

        if amount_paid > 0:
            payment_reference = clean_str(data.get("transactionId"), f"imported:{snap.id}")
            created = insert_do_nothing(
                conn,
                "payments",
                {
                    "id": new_id(),
                    "invoice_id": invoice_id,
                    "amount": amount_paid,
                    "payment_date": as_date(data.get("issueDate")),
                    "payment_method": map_payment_method(data.get("paymentMethod")),
                    "reference_number": payment_reference,
                    "notes": "Imported from legacy Firestore invoice amountPaid",
                    "created_at": as_datetime(data.get("createdAt")) or now_utc(),
                    "updated_at": now_utc(),
                },
                "(invoice_id, reference_number)",
            )
            if created:
                counters.payments += 1

    if fallback_customer_id:
        logger.info("Created fallback customers for invoices with missing customer references.")


def migrate_expenses(conn: Connection, tenant_id: str, user_id: str, docs: list[DocumentSnapshot], counters: Counters) -> None:
    for snap in docs:
        data = snap.to_dict() or {}
        upsert_returning_id(
            conn,
            "expenses",
            {
                "id": new_id(),
                "firestore_id": snap.id,
                "tenant_id": tenant_id,
                "user_id": user_id,
                "description": clean_str(data.get("description"), "Legacy expense"),
                "amount": money(data.get("amount")),
                "category": clean_str(data.get("category"), "General"),
                "date": as_date(data.get("date")),
                "vendor": data.get("vendor"),
                "reference_number": data.get("referenceNumber"),
                "receipt_url": data.get("receiptUrl") or data.get("receipt_url"),
                "is_tax_deductible": as_bool(data.get("isTaxDeductible"), True),
                "is_capital_expenditure": as_bool(data.get("isCapitalExpenditure"), False),
                "notes": data.get("notes"),
                "vat_amount": money(data.get("vatAmount")),
                "created_at": as_datetime(data.get("createdAt")) or now_utc(),
                "updated_at": now_utc(),
            },
            "(tenant_id, firestore_id)",
            [
                "description",
                "amount",
                "category",
                "date",
                "vendor",
                "reference_number",
                "receipt_url",
                "is_tax_deductible",
                "is_capital_expenditure",
                "notes",
                "vat_amount",
                "updated_at",
            ],
        )
        counters.expenses += 1


def migrate_user(conn: Connection, user_ref: DocumentReference, counters: Counters) -> None:
    firebase_uid = user_ref.id
    profile = get_profile(user_ref)
    tenant_id, user_id = create_tenant_and_owner(conn, firebase_uid, profile, counters)

    customers = get_subcollection(user_ref, "customers")
    inventory = get_subcollection(user_ref, "inventory")
    history = get_subcollection(user_ref, "inventoryHistory")
    invoices = get_subcollection(user_ref, "invoices")
    expenses = get_subcollection(user_ref, "expenses")

    logger.info(
        "Migrating %s: %s customers, %s inventory, %s history, %s invoices, %s expenses",
        firebase_uid,
        len(customers),
        len(inventory),
        len(history),
        len(invoices),
        len(expenses),
    )

    customer_map = migrate_customers(conn, tenant_id, customers, counters)
    product_map = migrate_inventory(conn, tenant_id, inventory, counters)
    migrate_history(conn, tenant_id, history, product_map, user_id, counters)
    migrate_invoices(conn, tenant_id, user_id, invoices, customer_map, product_map, counters)
    migrate_expenses(conn, tenant_id, user_id, expenses, counters)


def make_engine() -> Engine:
    settings = get_settings()
    url = settings.sync_database_url
    if "REPLACE_" in url:
        raise RuntimeError("DATABASE_URL_SYNC still contains REPLACE_ placeholders in backend/.env")
    return create_engine(url, future=True, pool_pre_ping=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Migrate Firestore user data into PostgreSQL.")
    parser.add_argument("--service-account", required=True, help="Path to Firebase Admin service account JSON.")
    parser.add_argument("--limit-users", type=int, default=0, help="Only migrate first N Firestore users.")
    parser.add_argument("--only-user", default="", help="Only migrate one Firebase UID.")
    parser.add_argument(
        "--source",
        choices=["auth", "firestore"],
        default="auth",
        help="Use Firebase Auth UIDs or concrete Firestore users documents as the user source.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Read data and roll back DB writes.")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(message)s",
    )

    service_account = Path(args.service_account).resolve()
    if not service_account.exists():
        raise FileNotFoundError(service_account)

    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(service_account)))
    db = firestore.client()
    engine = make_engine()
    counters = Counters()

    user_collection = db.collection("users")
    if args.only_user:
        user_refs = [user_collection.document(args.only_user)]
    elif args.source == "firestore":
        user_docs = list(user_collection.limit(args.limit_users).stream()) if args.limit_users else list(user_collection.stream())
        user_refs = [doc.reference for doc in user_docs if doc.exists]
    else:
        user_refs = []
        page = auth.list_users()
        for user in page.iterate_all():
            user_refs.append(user_collection.document(user.uid))
            if args.limit_users and len(user_refs) >= args.limit_users:
                break

    logger.info("Found %s Firebase user references to migrate from %s.", len(user_refs), args.source)

    with engine.connect() as conn:
        trans = conn.begin()
        try:
            for user_ref in user_refs:
                try:
                    migrate_user(conn, user_ref, counters)
                except Exception as exc:
                    counters.errors.append(f"{user_ref.id}: {exc}")
                    logger.exception("Failed migrating %s", user_ref.id)
            if args.dry_run or counters.errors:
                trans.rollback()
                logger.info("Rolled back migration%s.", " because errors occurred" if counters.errors else " due to --dry-run")
            else:
                trans.commit()
                logger.info("Committed migration.")
        except Exception:
            trans.rollback()
            raise

    logger.info("Migration summary: %s", counters)
    return 1 if counters.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
