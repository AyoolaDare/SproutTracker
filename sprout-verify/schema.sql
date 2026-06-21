-- Sprout Verify D1 schema
-- Public, read-only verification projection for signed receipts and invoices.
-- Run from sprout-verify/:
-- wrangler d1 execute sprout-verify --file schema.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS public_keys (
    key_id          TEXT PRIMARY KEY,
    public_key_pem  TEXT NOT NULL,
    algorithm       TEXT NOT NULL DEFAULT 'ECDSA_P256_SHA256',
    is_active       INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS receipts (
    receipt_id      TEXT PRIMARY KEY,
    document_type   TEXT NOT NULL DEFAULT 'RECEIPT'
        CHECK (document_type IN ('RECEIPT', 'INVOICE', 'PROFORMA', 'QUOTATION')),
    business_name   TEXT NOT NULL,
    customer_name   TEXT NOT NULL,
    items           TEXT NOT NULL CHECK (json_valid(items)),
    total           INTEGER NOT NULL CHECK (total >= 0),
    currency        TEXT NOT NULL DEFAULT 'NGN',
    date            TEXT NOT NULL,
    issued_by       TEXT NOT NULL,
    status          TEXT NOT NULL DEFAULT 'ISSUED',
    key_id          TEXT NOT NULL,
    signature       TEXT NOT NULL,
    canonical_data  TEXT NOT NULL,
    inserted_at     TEXT NOT NULL DEFAULT (datetime('now')),

    FOREIGN KEY (key_id) REFERENCES public_keys(key_id)
);

CREATE TABLE IF NOT EXISTS receipt_events (
    event_id          TEXT PRIMARY KEY,
    target_receipt_id TEXT NOT NULL,
    event_type        TEXT NOT NULL CHECK (event_type IN ('VOID', 'REISSUE')),
    reason            TEXT,
    replacement_id    TEXT,
    created_at        TEXT NOT NULL DEFAULT (datetime('now')),

    FOREIGN KEY (target_receipt_id) REFERENCES receipts(receipt_id),
    FOREIGN KEY (replacement_id) REFERENCES receipts(receipt_id)
);

CREATE INDEX IF NOT EXISTS idx_receipts_key_id ON receipts(key_id);
CREATE INDEX IF NOT EXISTS idx_receipt_events_target ON receipt_events(target_receipt_id);

CREATE TRIGGER IF NOT EXISTS receipts_no_update
BEFORE UPDATE ON receipts
BEGIN
    SELECT RAISE(ABORT, 'receipts are immutable');
END;

CREATE TRIGGER IF NOT EXISTS receipts_no_delete
BEFORE DELETE ON receipts
BEGIN
    SELECT RAISE(ABORT, 'receipts are immutable');
END;

CREATE TRIGGER IF NOT EXISTS receipt_events_no_update
BEFORE UPDATE ON receipt_events
BEGIN
    SELECT RAISE(ABORT, 'receipt events are immutable');
END;

CREATE TRIGGER IF NOT EXISTS receipt_events_no_delete
BEFORE DELETE ON receipt_events
BEGIN
    SELECT RAISE(ABORT, 'receipt events are immutable');
END;

-- Example public key:
-- INSERT INTO public_keys (key_id, public_key_pem) VALUES (
--   'sprout-key-2026-01',
--   '-----BEGIN PUBLIC KEY-----
-- MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
-- -----END PUBLIC KEY-----'
-- );

-- Example signed public record:
-- INSERT INTO receipts (
--   receipt_id, document_type, business_name, customer_name, items, total,
--   currency, date, issued_by, status, key_id, signature, canonical_data
-- ) VALUES (
--   'RCP-2026-06-21-7A3F9E2D',
--   'RECEIPT',
--   'Sprout Track Demo Store',
--   'ABC Store',
--   '[{"name":"Rice 50kg","qty":2,"amount":6400}]',
--   6400,
--   'NGN',
--   '2026-06-21T14:32:00Z',
--   'John',
--   'ISSUED',
--   'sprout-key-2026-01',
--   'BASE64_OR_BASE64URL_ECDSA_SIGNATURE',
--   '{"business_name":"Sprout Track Demo Store","currency":"NGN","customer_name":"ABC Store","date":"2026-06-21T14:32:00Z","document_type":"RECEIPT","issued_by":"John","items":[{"amount":6400,"name":"Rice 50kg","qty":2}],"receipt_id":"RCP-2026-06-21-7A3F9E2D","status":"ISSUED","total":6400}'
-- );
