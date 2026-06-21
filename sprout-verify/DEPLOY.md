# Sprout Verify - Cloudflare Deployment

Public receipt and invoice verification for Sprout Track.

Production URL:

```text
https://verify.sprouttracker.name.ng
```

This is a public, read-only verifier. No login. No session. No direct connection to the main Sprout app database.

## Architecture

```text
Sprout Track app
  -> creates receipt/invoice
  -> signs canonical public payload with AWS KMS ECDSA P-256 SHA-256
  -> exports public fields + signature to Cloudflare D1
  -> QR code links to https://verify.sprouttracker.name.ng/{receipt_id}

Visitor
  -> opens verifier page
  -> types ID or scans QR
  -> Cloudflare Pages Function checks D1
  -> Worker verifies ECDSA signature on every request
```

## Files

```text
sprout-verify/
  public/
    index.html       Search + QR scanner page
    verify.html      Result shell
    app.js           Vanilla JS lookup + QR scanner
    style.css        Mobile-first UI
    _headers         Security headers
    _redirects       /{id} -> verify page
  functions/
    _verify_core.js
    api/health.js
    api/verify/[receipt_id].js
  src/index.js       Optional standalone Worker entry
  schema.sql         D1 schema
  wrangler.toml      Cloudflare config
```

## One-Time Setup

Install Wrangler:

```bash
npm install -g wrangler
wrangler login
```

Create D1:

```bash
cd SproutStat/sprout-verify
wrangler d1 create sprout-verify
```

Copy the returned `database_id` into `wrangler.toml`:

```toml
[[d1_databases]]
binding = "DB"
database_name = "sprout-verify"
database_id = "PASTE_ID_HERE"
```

Apply the schema:

```bash
wrangler d1 execute sprout-verify --file schema.sql
```

Create the Pages project:

```bash
wrangler pages project create sprout-verify --production-branch main
```

Deploy:

```bash
wrangler pages deploy public --project-name sprout-verify
```

Important: run the deploy command from the `sprout-verify` folder so Wrangler sees the `functions/` directory.

## Domain

In Cloudflare Pages:

1. Open `sprout-verify`.
2. Go to `Custom domains`.
3. Add:

```text
verify.sprouttracker.name.ng
```

4. Follow Cloudflare DNS instructions until SSL is active.

## API

Health:

```http
GET /api/health
```

Verify:

```http
GET /api/verify/{receipt_id}
```

Valid:

```json
{
  "found": true,
  "valid": true,
  "receipt": {
    "receipt_id": "RCP-2026-06-21-7A3F9E2D",
    "document_type": "RECEIPT",
    "business_name": "Sprout Track Demo Store",
    "customer_name": "ABC Store",
    "items": [{"name": "Rice 50kg", "qty": 2, "amount": 6400}],
    "total": 6400,
    "currency": "NGN",
    "date": "2026-06-21T14:32:00Z",
    "issued_by": "John",
    "status": "ISSUED",
    "verified_at": "2026-06-21T15:15:00Z"
  }
}
```

Invalid:

```json
{"found": true, "valid": false, "error": "Signature failed"}
```

Not found:

```json
{"found": false, "valid": false, "error": "Not found"}
```

## Security Model

Implemented:

- Public read-only API.
- `GET` and `OPTIONS` only.
- No auth and no cookies.
- D1 stores only public fields.
- No user IDs, phone numbers, emails, costs, margins, internal notes, or tenant IDs.
- Receipt rows are immutable with D1 triggers.
- Void/reissue actions are append-only events in `receipt_events`.
- ECDSA P-256 SHA-256 signature checked on every verification request.
- AWS KMS DER signatures are normalized before Web Crypto verification.
- Invalid/not-found responses are never cached.
- Static pages use CSP, no inline JavaScript, no third-party scripts.
- QR scanner uses browser camera only after the visitor taps `Scan QR code`.

The trust rule:

```text
If an attacker controls the website code, they can take verification offline,
but they cannot forge valid receipts without the private signing key.
```

That assumes:

- The private signing key stays in AWS KMS.
- D1 writes are done only by a trusted backend/export job.
- The canonical payload is stable and signed before insertion.

## Canonical Payload

Sign the exact JSON string inserted into `canonical_data`.

Recommended deterministic key order:

```json
{
  "business_name": "Sprout Track Demo Store",
  "currency": "NGN",
  "customer_name": "ABC Store",
  "date": "2026-06-21T14:32:00Z",
  "document_type": "RECEIPT",
  "issued_by": "John",
  "items": [{"amount": 6400, "name": "Rice 50kg", "qty": 2}],
  "receipt_id": "RCP-2026-06-21-7A3F9E2D",
  "status": "ISSUED",
  "total": 6400
}
```

AWS KMS recommendation:

- Key spec: `ECC_NIST_P256`
- Signing algorithm: `ECDSA_SHA_256`
- Message type: `RAW`
- Store the returned DER signature as base64/base64url in `signature`.

## Main App Integration

Set the QR/link target in the main Sprout app to:

```text
https://verify.sprouttracker.name.ng/{receipt_id}
```

If using the backend setting added for PDFs/emails:

```text
VERIFY_FRONTEND_URL=https://verify.sprouttracker.name.ng
```

## Production Test

```bash
curl https://verify.sprouttracker.name.ng/api/health
curl https://verify.sprouttracker.name.ng/api/verify/RCP-2026-06-21-7A3F9E2D
```

Then open:

```text
https://verify.sprouttracker.name.ng/RCP-2026-06-21-7A3F9E2D
```
