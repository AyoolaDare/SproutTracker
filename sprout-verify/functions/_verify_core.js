const RECEIPT_ID_PATTERN = /^[A-Za-z0-9_-]{3,96}$/;

const API_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Max-Age': '86400',
  'Content-Type': 'application/json; charset=utf-8',
  'X-Content-Type-Options': 'nosniff',
};

export function jsonResponse(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...API_HEADERS, ...extraHeaders },
  });
}

export function optionsResponse() {
  return new Response(null, { status: 204, headers: API_HEADERS });
}

export function methodNotAllowed() {
  return jsonResponse(
    { found: false, valid: false, error: 'Method not allowed' },
    405,
    { Allow: 'GET, OPTIONS', 'Cache-Control': 'no-store' },
  );
}

function base64ToBytes(value) {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padded = normalized + '='.repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function pemToBytes(pem) {
  return base64ToBytes(
    pem
      .replace('-----BEGIN PUBLIC KEY-----', '')
      .replace('-----END PUBLIC KEY-----', '')
      .replace(/\s/g, ''),
  );
}

function readDerLength(bytes, offset) {
  let length = bytes[offset];
  offset += 1;
  if ((length & 0x80) === 0) return { length, offset };

  const lengthBytes = length & 0x7f;
  length = 0;
  for (let i = 0; i < lengthBytes; i += 1) {
    length = (length << 8) | bytes[offset + i];
  }
  return { length, offset: offset + lengthBytes };
}

function readDerInteger(bytes, offset) {
  if (bytes[offset] !== 0x02) {
    throw new Error('Invalid DER signature integer');
  }
  const lengthInfo = readDerLength(bytes, offset + 1);
  const start = lengthInfo.offset;
  const end = start + lengthInfo.length;
  let value = bytes.slice(start, end);

  while (value.length > 0 && value[0] === 0) {
    value = value.slice(1);
  }
  if (value.length > 32) {
    throw new Error('DER integer is too large for P-256');
  }
  const padded = new Uint8Array(32);
  padded.set(value, 32 - value.length);
  return { value: padded, offset: end };
}

function normalizeP256Signature(signatureBytes) {
  if (signatureBytes.length === 64) {
    return signatureBytes;
  }
  if (signatureBytes[0] !== 0x30) {
    throw new Error('Unsupported ECDSA signature format');
  }

  const sequenceLength = readDerLength(signatureBytes, 1);
  let offset = sequenceLength.offset;
  const r = readDerInteger(signatureBytes, offset);
  offset = r.offset;
  const s = readDerInteger(signatureBytes, offset);

  const raw = new Uint8Array(64);
  raw.set(r.value, 0);
  raw.set(s.value, 32);
  return raw;
}

async function importPublicKey(publicKeyPem) {
  return crypto.subtle.importKey(
    'spki',
    pemToBytes(publicKeyPem).buffer,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['verify'],
  );
}

export async function verifySignature(canonicalData, signature, publicKeyPem) {
  try {
    const publicKey = await importPublicKey(publicKeyPem);
    const signatureBytes = normalizeP256Signature(base64ToBytes(signature));
    const dataBytes = new TextEncoder().encode(canonicalData);

    return await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      publicKey,
      signatureBytes,
      dataBytes,
    );
  } catch (error) {
    console.error('signature_verify_failed', error.message);
    return false;
  }
}

function parseItems(value) {
  try {
    const parsed = JSON.parse(value || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function publicReceiptPayload(row) {
  return {
    receipt_id: row.receipt_id,
    document_type: row.document_type || 'RECEIPT',
    business_name: row.business_name,
    customer_name: row.customer_name,
    items: parseItems(row.items),
    total: Number(row.total || 0),
    currency: row.currency || 'NGN',
    date: row.date,
    issued_by: row.issued_by,
    status: row.status || 'ISSUED',
    verified_at: new Date().toISOString(),
  };
}

export async function verifyReceipt(receiptId, env) {
  if (!RECEIPT_ID_PATTERN.test(receiptId || '')) {
    return jsonResponse(
      { found: false, valid: false, error: 'Invalid receipt or invoice ID format.' },
      400,
      { 'Cache-Control': 'no-store' },
    );
  }

  if (!env.DB) {
    return jsonResponse(
      { found: false, valid: false, error: 'Verification database is not configured.' },
      500,
      { 'Cache-Control': 'no-store' },
    );
  }

  try {
    const receipt = await env.DB.prepare(
      `SELECT receipt_id, document_type, business_name, customer_name, items, total, currency,
              date, issued_by, status, signature, key_id, canonical_data,
              (
                SELECT created_at
                  FROM receipt_events
                 WHERE target_receipt_id = receipts.receipt_id
                   AND event_type = 'VOID'
                 ORDER BY created_at DESC
                 LIMIT 1
              ) AS voided_at
         FROM receipts
        WHERE receipt_id = ?`,
    ).bind(receiptId).first();

    if (!receipt) {
      return jsonResponse(
        { found: false, valid: false, error: 'Not found' },
        404,
        { 'Cache-Control': 'no-store' },
      );
    }

    if (receipt.voided_at) {
      return jsonResponse(
        { found: true, valid: false, error: 'This document has been voided.' },
        200,
        { 'Cache-Control': 'no-store' },
      );
    }

    const key = await env.DB.prepare(
      'SELECT public_key_pem FROM public_keys WHERE key_id = ? AND is_active = 1',
    ).bind(receipt.key_id).first();

    if (!key) {
      return jsonResponse(
        { found: true, valid: false, error: 'Signing key not found.' },
        200,
        { 'Cache-Control': 'no-store' },
      );
    }

    const valid = await verifySignature(
      receipt.canonical_data,
      receipt.signature,
      key.public_key_pem,
    );

    if (!valid) {
      return jsonResponse(
        { found: true, valid: false, error: 'Signature failed' },
        200,
        { 'Cache-Control': 'no-store' },
      );
    }

    return jsonResponse(
      { found: true, valid: true, receipt: publicReceiptPayload(receipt) },
      200,
      { 'Cache-Control': 'public, max-age=60, s-maxage=60' },
    );
  } catch (error) {
    console.error('verify_error', error.message);
    return jsonResponse(
      { found: false, valid: false, error: 'Verification service unavailable.' },
      500,
      { 'Cache-Control': 'no-store' },
    );
  }
}
