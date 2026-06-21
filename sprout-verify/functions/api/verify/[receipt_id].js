import { methodNotAllowed, optionsResponse, verifyReceipt } from '../../_verify_core.js';

export async function onRequest(context) {
  if (context.request.method === 'OPTIONS') return optionsResponse();
  if (context.request.method !== 'GET') return methodNotAllowed();

  return verifyReceipt(context.params.receipt_id, context.env);
}
