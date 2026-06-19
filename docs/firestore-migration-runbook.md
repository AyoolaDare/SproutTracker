# Firestore Migration Runbook

This migrates the old Firebase shape into Supabase PostgreSQL.

## 1. Prerequisites

In `backend/.env`, replace all placeholders for:

```text
DATABASE_URL
DATABASE_URL_SYNC
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
REDIS_URL
JWT_SECRET
JWT_REFRESH_SECRET
```

Install backend dependencies:

```bash
cd backend
pip install -r requirements.txt
```

Run the database migration first:

```bash
python -m alembic upgrade head
```

## 2. Dry Run One User

Use the rotated Firebase service account JSON that is ignored by git:

```bash
python scripts/migrate_firestore_to_postgres.py \
  --service-account ../bizbalance-o2v9w-firebase-adminsdk-fbsvc-d8e0f26993.json \
  --limit-users 1 \
  --dry-run
```

This reads Firestore and writes inside a transaction, then rolls back.

## 3. Dry Run All Users

```bash
python scripts/migrate_firestore_to_postgres.py \
  --service-account ../bizbalance-o2v9w-firebase-adminsdk-fbsvc-d8e0f26993.json \
  --dry-run
```

Review the summary counts.

## 4. Real Migration

```bash
python scripts/migrate_firestore_to_postgres.py \
  --service-account ../bizbalance-o2v9w-firebase-adminsdk-fbsvc-d8e0f26993.json
```

The script is idempotent for top-level imported records because it stores legacy IDs in PostgreSQL:

- `tenants.firebase_user_id`
- `users.firebase_uid`
- `customers.firestore_id`
- `products.firestore_id`
- `inventory_batches.firestore_id`
- `stock_movements.firestore_id`
- `invoices.firestore_id`
- `expenses.firestore_id`

## 5. After Migration

Check Supabase table counts, then clear Upstash dashboard cache if needed:

```text
sprout-track:dashboard:*
```

New migrated users receive random unusable passwords. They should use your future password reset/invite flow before logging into the new backend.

## 6. Activate Migrated Users

After running `alembic upgrade head` with the password activation migration, create setup links:

```bash
python scripts/create_activation_links.py --frontend-url https://your-vercel-app.vercel.app
```

For one user:

```bash
python scripts/create_activation_links.py --frontend-url https://your-vercel-app.vercel.app --email user@example.com
```

Send each user their link. The frontend should collect the new password and call:

```text
POST /api/auth/password-reset/confirm
{
  "token": "...",
  "password": "new password"
}
```

Do not ask migrated users to sign up again with the same email. They should activate the existing migrated account so their invoices, customers, inventory, and expenses remain attached.
