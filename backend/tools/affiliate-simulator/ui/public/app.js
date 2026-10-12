// Page logic for the affiliate simulator. All text from the server is put in
// with textContent, never as HTML.

const $ = (id) => document.getElementById(id);
const el = (tag, props = {}, ...kids) => {
  const node = Object.assign(document.createElement(tag), props);
  for (const k of kids) node.append(k);
  return node;
};

let config = null;
let lastTransactionId = '';
let busy = false;

async function api(path, body) {
  const res = await fetch(path, body === undefined ? {} : { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.message ?? `The tool answered ${res.status}.`);
  return data;
}

function showBanner(kind, text) {
  const b = $('banner');
  b.hidden = !text;
  b.className = 'banner ' + kind;
  b.textContent = text ?? '';
}

function renderConfig() {
  const t = $('target');
  t.replaceChildren(
    el('span', { textContent: 'Target ' }),
    el('code', { textContent: config.target }),
    el('span', { className: 'pill ' + (config.targetOk ? (config.targetLocal ? 'ok' : 'warn') : 'bad'), textContent: config.targetOk ? (config.targetLocal ? 'local' : 'REMOTE') : 'blocked' }),
    el('span', { className: 'pill ' + (config.tokenSet ? 'ok' : 'bad'), textContent: config.tokenSet ? 'token set' : 'no token' }),
  );
  if (!config.targetOk) showBanner('bad', config.targetProblem);
  else if (!config.tokenSet) showBanner('bad', 'SM_WEBHOOK_TOKEN is not set. Restart the tool with the Webhooks:CuelinksToken value; sending is disabled until then.');
  else if (!config.targetLocal) showBanner('warn', 'This is not a local address. Simulated sales will be written to that server.');
  else showBanner('', null);

  const wrap = $('scenarios');
  wrap.replaceChildren(...config.scenarios.map((s) => {
    const b = el('button', { type: 'button', className: 'scenario', id: 'scn-' + s.key },
      el('span', { className: 'name', textContent: s.label }),
      el('span', { className: 'steps', textContent: s.steps.join(' → ') }),
      el('span', { className: 'help', textContent: s.help }));
    b.addEventListener('click', () => run('/api/scenario', { scenario: s.key }, s.label));
    return b;
  }));
  $('status').replaceChildren(...config.statuses.map((s) => el('option', { value: s, textContent: s })));
  updateEnabled();
}

function updateEnabled() {
  const ready = Boolean(config?.targetOk && config?.tokenSet) && !busy;
  for (const b of document.querySelectorAll('.scenario, #sendOne')) b.disabled = !ready;
  $('useLast').disabled = !lastTransactionId || busy;
}

function readFields() {
  return {
    subId: $('subId').value,
    commission: $('commission').value,
    saleAmount: $('saleAmount').value,
    transactionId: $('transactionId').value,
  };
}

async function run(path, extra, title) {
  if (busy) return;
  busy = true; updateEnabled();
  try {
    const data = await api(path, { ...readFields(), ...extra });
    lastTransactionId = data.transactionId;
    addLog(title, data);
  } catch (error) {
    addError(title, error.message);
  } finally {
    busy = false; updateEnabled();
  }
}

function addLog(title, data) {
  $('empty').hidden = true;
  const items = [el('li', { className: 'sep', textContent: `${new Date().toLocaleTimeString()}  ${title}` })];
  for (const r of data.results) {
    const ok = r.httpStatus >= 200 && r.httpStatus < 300;
    const head = el('div', { className: 'head' },
      el('strong', { textContent: `${r.step}. ${r.status}` }),
      el('span', { className: 'pill ' + (ok ? 'ok' : 'bad'), textContent: ok ? (r.outcome ?? 'OK') : (r.httpStatus ? `HTTP ${r.httpStatus}` : 'No answer') }),
      el('span', { className: 'tx', textContent: data.transactionId }));
    const detail = el('details', {},
      el('summary', { textContent: 'Request and response' }),
      el('pre', { textContent: JSON.stringify({ request: r.request, response: r.response }, null, 2) }));
    const meta = el('div', { className: 'meta', textContent: `sub_id ${r.sub_id}  ·  commission ₹${r.request.commission}  ·  ${r.ms} ms` });
    items.push(el('li', {}, head, meta, detail));
  }
  $('log').prepend(...items);
}

function addError(title, message) {
  $('empty').hidden = true;
  $('log').prepend(el('li', { className: 'sep', textContent: `${new Date().toLocaleTimeString()}  ${title}` }),
    el('li', {}, el('div', { className: 'head' }, el('span', { className: 'pill bad', textContent: 'Not sent' }), el('span', { textContent: message }))));
}

// ---- step 1: create a tracked click

function showNote(text, bad = false) {
  const n = $('clickNote');
  n.hidden = !text;
  n.className = 'note' + (bad ? ' bad' : '');
  n.textContent = text ?? '';
}

async function loadStores() {
  try {
    const { stores } = await api('/api/stores');
    $('clickStore').replaceChildren(el('option', { value: '', textContent: 'Choose a store…' }),
      ...stores.map((s) => el('option', { value: s.id, textContent: s.name })));
  } catch (error) {
    $('clickStore').replaceChildren(el('option', { value: '', textContent: 'Stores unavailable' }));
    showNote(`Could not load stores: ${error.message}`, true);
  }
}

$('clickForm').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (busy) return;
  busy = true; updateEnabled();
  $('makeClick').disabled = true;
  showNote(null);
  try {
    const data = await api('/api/click', { email: $('clickEmail').value, password: $('clickPassword').value, storeId: $('clickStore').value });
    $('subId').value = data.subId;
    $('clickPassword').value = '';
    const store = $('clickStore').selectedOptions[0]?.textContent ?? 'the store';
    showNote(`Click created for ${data.userEmail} on ${store}${data.merchant ? ` (${data.merchant})` : ''}. The subid is filled in below.`);
    updateExpected();
  } catch (error) {
    showNote(error.message, true);
  } finally {
    busy = false; updateEnabled();
    $('makeClick').disabled = false;
  }
});

// ---- the expected cashback hint

function updateExpected() {
  const commission = Number($('commission').value);
  const share = Number($('share').value);
  const out = $('expected');
  if (!Number.isFinite(commission) || !Number.isFinite(share) || commission < 0 || share < 0 || share > 100) {
    out.textContent = '';
    return;
  }
  const amount = Math.round((commission * share) / 100 * 100) / 100;
  const strong = el('strong', { textContent: `₹${amount.toFixed(2)}` });
  out.replaceChildren('Expected cashback: ', strong, `  (₹${commission} × ${share}%; a store override changes this)`);
}
$('commission').addEventListener('input', updateExpected);
$('share').addEventListener('input', updateExpected);
updateExpected();

$('sendOne').addEventListener('click', () => run('/api/postback', { status: $('status').value }, `One update: ${$('status').value}`));
$('useLast').addEventListener('click', () => { $('transactionId').value = lastTransactionId; });
$('clear').addEventListener('click', () => { $('log').replaceChildren(); $('empty').hidden = false; });

try {
  config = await api('/api/config');
  renderConfig();
  if (config.targetOk) await loadStores();
} catch (error) {
  showBanner('bad', `Could not load the tool's settings: ${error.message}`);
}
