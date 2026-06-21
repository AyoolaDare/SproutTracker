import { jsonResponse, optionsResponse, verifyReceipt } from '../functions/_verify_core.js';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return optionsResponse();
    }
    if (request.method !== 'GET') {
      return jsonResponse(
        { found: false, valid: false, error: 'Method not allowed' },
        405,
        { Allow: 'GET, OPTIONS', 'Cache-Control': 'no-store' },
      );
    }

    if (url.pathname === '/api/health') {
      let database = false;
      try {
        if (env.DB) {
          await env.DB.prepare('SELECT 1').first();
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

    const match = url.pathname.match(/^\/api\/verify\/([^/]+)$/);
    if (match) {
      return verifyReceipt(decodeURIComponent(match[1]), env);
    }

    return jsonResponse(
      { found: false, valid: false, error: 'Not found' },
      404,
      { 'Cache-Control': 'no-store' },
    );
  },
};
