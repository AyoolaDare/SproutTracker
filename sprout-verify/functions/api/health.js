import { jsonResponse, methodNotAllowed, optionsResponse } from '../_verify_core.js';

export async function onRequest(context) {
  if (context.request.method === 'OPTIONS') return optionsResponse();
  if (context.request.method !== 'GET') return methodNotAllowed();

  let database = false;
  try {
    if (context.env.DB) {
      await context.env.DB.prepare('SELECT 1').first();
      database = true;
    }
  } catch {
    database = false;
  }

  return jsonResponse({
    status: database ? 'ok' : 'degraded',
    service: 'sprout-verify',
    database,
    timestamp: new Date().toISOString(),
  }, database ? 200 : 503, { 'Cache-Control': 'no-store' });
}
