const ID_PATTERN = /^[A-Za-z0-9_-]{3,96}$/;

let activeStream = null;
let scanTimer = null;

function escapeHtml(value) {
  const div = document.createElement('div');
  div.textContent = String(value ?? '');
  return div.innerHTML;
}

function formatCurrency(amount, currency = 'NGN') {
  const value = Number(amount || 0);
  try {
    return new Intl.NumberFormat('en-NG', {
      style: 'currency',
      currency,
      maximumFractionDigits: 2,
    }).format(value);
  } catch {
    return `${currency} ${value.toLocaleString('en-NG')}`;
  }
}

function formatDate(value) {
  if (!value) return 'N/A';
  try {
    return new Date(value).toLocaleString('en-NG', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return value;
  }
}

function extractId(value) {
  const trimmed = String(value || '').trim();
  if (!trimmed) return '';

  try {
    const parsed = new URL(trimmed);
    const parts = parsed.pathname.split('/').filter(Boolean);
    return (parts[parts.length - 1] || '').replace(/[^A-Za-z0-9_-]/g, '');
  } catch {
    return trimmed.replace(/[^A-Za-z0-9_-]/g, '');
  }
}

function goToId(value) {
  const id = extractId(value);
  if (!ID_PATTERN.test(id)) return false;
  stopScanner();
  window.location.href = `/${encodeURIComponent(id)}`;
  return true;
}

function logoHtml() {
  return `
    <section class="logo" aria-label="Sprout Track">
      <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <circle cx="32" cy="32" r="30" fill="#2a3024" stroke="#7a8f5c" stroke-width="2"/>
        <path d="M32 44V28" stroke="#7a8f5c" stroke-width="3" stroke-linecap="round"/>
        <path d="M32 28C32 28 24 24 24 18C24 12 32 14 32 14C32 14 40 12 40 18C40 24 32 28 32 28Z" fill="#7a8f5c"/>
        <path d="M32 44C32 44 22 40 22 32" stroke="#7a8f5c" stroke-width="2.5" stroke-linecap="round"/>
        <path d="M32 44C32 44 42 40 42 32" stroke="#7a8f5c" stroke-width="2.5" stroke-linecap="round"/>
        <circle cx="32" cy="48" r="2" fill="#d4a85a"/>
      </svg>
      <div class="logo-text">Sprout Verify</div>
      <div class="logo-sub">Receipt & Invoice Verification</div>
    </section>
  `;
}

function searchAgainHtml() {
  return `
    <section class="card">
      <form class="search-form" data-verify-form>
        <input class="input-field" data-receipt-input placeholder="Verify another ID..." maxlength="96" required>
        <button type="submit" class="btn btn-primary">Verify</button>
      </form>
    </section>
  `;
}

function renderVerified(data) {
  const receipt = data.receipt;
  const items = Array.isArray(receipt.items) ? receipt.items : [];
  const currency = receipt.currency || 'NGN';
  const rows = items.map((item) => {
    const qty = Number(item.qty || item.quantity || 1);
    const amount = Number(item.amount || item.total || 0);
    return `
      <tr>
        <td>${escapeHtml(item.name || item.description || 'Item')}</td>
        <td class="col-qty">${escapeHtml(qty)}</td>
        <td class="col-total">${formatCurrency(amount, currency)}</td>
      </tr>
    `;
  }).join('');

  return `
    ${logoHtml()}
    <section class="card">
      <div class="receipt-header">
        <div class="receipt-status status-valid">Valid - Verified by Sprout</div>
        <div class="receipt-id">${escapeHtml(receipt.receipt_id)}</div>
      </div>
      <h2>${escapeHtml(receipt.customer_name)}</h2>
      <p>${escapeHtml(receipt.business_name)} issued this ${escapeHtml(receipt.document_type || 'record')}.</p>

      ${rows ? `
        <table class="items-table">
          <thead>
            <tr>
              <th>Item</th>
              <th class="col-qty">Qty</th>
              <th class="col-total">Amount</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      ` : ''}

      <div class="total-row">
        <span class="total-label">Total</span>
        <span class="total-amount">${formatCurrency(receipt.total, currency)}</span>
      </div>

      <ul class="meta-list">
        <li><span class="meta-label">Date</span><span class="meta-value">${escapeHtml(formatDate(receipt.date))}</span></li>
        <li><span class="meta-label">Issued by</span><span class="meta-value">${escapeHtml(receipt.issued_by)}</span></li>
        <li><span class="meta-label">Status</span><span class="meta-value">${escapeHtml(receipt.status)}</span></li>
        <li><span class="meta-label">Verified at</span><span class="meta-value">${escapeHtml(formatDate(receipt.verified_at))}</span></li>
      </ul>
    </section>
    ${searchAgainHtml()}
    <footer class="footer">Signature checked on every request.</footer>
  `;
}

function renderMessage(title, message, tone) {
  return `
    ${logoHtml()}
    <section class="card">
      <div class="message">
        <div class="message-icon ${tone}"></div>
        <div class="message-title">${escapeHtml(title)}</div>
        <p class="message-text">${escapeHtml(message)}</p>
      </div>
    </section>
    ${searchAgainHtml()}
  `;
}

function bindForms() {
  document.querySelectorAll('[data-verify-form]').forEach((form) => {
    form.addEventListener('submit', (event) => {
      event.preventDefault();
      const input = form.querySelector('[data-receipt-input]');
      if (!goToId(input.value)) {
        input.focus();
        input.setCustomValidity('Enter a valid receipt or invoice ID.');
        input.reportValidity();
        setTimeout(() => input.setCustomValidity(''), 1000);
      }
    });
  });
}

async function startScanner() {
  const scanner = document.querySelector('[data-scanner]');
  const video = document.querySelector('[data-scan-video]');
  const status = document.querySelector('[data-scan-status]');

  if (!('BarcodeDetector' in window)) {
    status.textContent = 'QR scanning is not supported in this browser. Type the ID instead.';
    scanner.hidden = false;
    return;
  }

  try {
    activeStream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: 'environment' },
      audio: false,
    });
    video.srcObject = activeStream;
    await video.play();
    scanner.hidden = false;
    status.textContent = 'Scanning...';

    const detector = new BarcodeDetector({ formats: ['qr_code'] });
    scanTimer = window.setInterval(async () => {
      try {
        const codes = await detector.detect(video);
        if (codes.length && goToId(codes[0].rawValue)) {
          status.textContent = 'QR found.';
        }
      } catch {
        status.textContent = 'Keep the QR code inside the frame.';
      }
    }, 450);
  } catch {
    scanner.hidden = false;
    status.textContent = 'Camera permission was blocked. Type the ID instead.';
  }
}

function stopScanner() {
  if (scanTimer) {
    window.clearInterval(scanTimer);
    scanTimer = null;
  }
  if (activeStream) {
    activeStream.getTracks().forEach((track) => track.stop());
    activeStream = null;
  }
}

async function verifyFromPath() {
  const app = document.querySelector('[data-verify-app]');
  const id = extractId(window.location.pathname);

  if (!ID_PATTERN.test(id)) {
    app.innerHTML = renderMessage('Invalid ID', 'This receipt or invoice ID is not valid.', 'error');
    bindForms();
    return;
  }

  try {
    const response = await fetch(`/api/verify/${encodeURIComponent(id)}`, {
      headers: { Accept: 'application/json' },
    });
    const data = await response.json();

    if (!data.found) {
      app.innerHTML = renderMessage('Not Found', data.error || 'This record was not found.', 'error');
    } else if (!data.valid) {
      app.innerHTML = renderMessage('Invalid Record', data.error || 'Signature failed.', 'warning');
    } else {
      app.innerHTML = renderVerified(data);
    }
  } catch {
    app.innerHTML = renderMessage('Verification Unavailable', 'Please try again later.', 'error');
  }
  bindForms();
}

document.addEventListener('DOMContentLoaded', () => {
  bindForms();

  document.querySelector('[data-scan-start]')?.addEventListener('click', startScanner);
  document.querySelector('[data-scan-stop]')?.addEventListener('click', stopScanner);

  if (document.body.dataset.page === 'verify') {
    verifyFromPath();
  }
});
