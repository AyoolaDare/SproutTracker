# Sprout Track Production Backend

## Stack

- FastAPI on Render using the `backend/Dockerfile`.
- Supabase PostgreSQL as the primary database.
- Upstash Redis for rate limiting, dashboard caching, token revocation, and future queues.
- Supabase Storage for receipt, logo, and generated PDF assets.
- Sentry is recommended for production error monitoring.

## Provisioning

1. Create a Supabase project and copy the pooled or direct Postgres connection string.
2. Create an Upstash Redis database and copy the TLS `rediss://` URL.
3. Create a private Supabase Storage bucket named `sprout-track`.
4. Create a Render Blueprint from `render.yaml`.
5. Set all `sync: false` variables in Render using `backend/.env.example` as the checklist.
6. Deploy. The container runs `alembic upgrade head` before starting Uvicorn.

## Required Render Environment Variables

- `ENVIRONMENT=production`
- `DATABASE_URL`
- `DATABASE_URL_SYNC`
- `REDIS_URL`
- `REDIS_REQUIRED=true`
- `FRONTEND_URL`
- `CORS_ORIGINS`
- `TRUSTED_HOSTS`
- `JWT_SECRET`
- `JWT_REFRESH_SECRET`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_STORAGE_BUCKET`

`DATABASE_URL` can be `postgresql://...`; the application normalizes it to `postgresql+asyncpg://...`.

## Redis Usage

- `rate:*`: fixed-window API and login rate limits.
- `dashboard:{tenant_id}:metrics`: short-lived dashboard cache.
- `jwt:revoked:{jti}`: revoked access tokens until their natural expiry.
- Future queue namespaces should use `jobs:*` and `notifications:*`.

Redis is not used as a primary database. Supabase PostgreSQL remains the source of truth.

## Database

The initial schema lives in `backend/alembic/versions/0001_initial_schema.py` and includes tenants, users, customers, products, FIFO inventory batches, stock movements, invoices, invoice items, batch allocations, payments, expenses, tax settings, and audit logs.

For local migration checks:

```bash
cd backend
alembic upgrade head
```

## Security Notes

- Production startup fails if JWT secrets are weak.
- API rate limiting fails open if Redis is unavailable unless `REDIS_REQUIRED=true`.
- Dashboard cache is invalidated after invoice, inventory, product, customer, expense, and settings writes.
- `/api/auth/revoke` stores the current access-token `jti` in Redis until token expiry.
- CORS and trusted hosts must be set to real deployed domains before production traffic.

## Recommended Add-ons

- Sentry for exceptions and traces through `SENTRY_DSN`.
- Render log drains if you want long-term auditability outside Render.
- Supabase database backups enabled before launch.
