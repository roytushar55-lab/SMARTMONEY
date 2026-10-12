import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { SCENARIOS, STATUSES, InputError, buildPostback, checkTarget, expectedCashback, newTransactionId, validateInput } from './postback.mjs';
import { createHandler, readConfig } from './server.mjs';

test('payload has the exact Cuelinks field names and sensible dates', () => {
  const now = new Date('2026-10-12T10:00:00Z');
  const p = buildPostback({ transactionId: 'T1', subId: 'abc', status: 'validated', commission: 400, saleAmount: 4000, now });
  assert.deepEqual(Object.keys(p).sort(), ['campaign_id', 'commission', 'currency', 'sale_amount', 'status', 'sub_id', 'transaction_date', 'transaction_id', 'updated_at']);
  assert.equal(p.transaction_id, 'T1');
  assert.equal(p.sub_id, 'abc');
  assert.equal(p.commission, 400);
  assert.equal(p.currency, 'INR');
  assert.equal(p.updated_at, '2026-10-12T10:00:00.000Z');
  assert.equal(p.transaction_date, '2026-10-12T08:00:00.000Z'); // two hours earlier
});

test('scenarios match Send-Postback.ps1', () => {
  const steps = (k) => SCENARIOS[k].steps.map((s) => s.status);
  assert.deepEqual(steps('happy-path'), ['pending', 'validated', 'paid']);
  assert.deepEqual(steps('rejected'), ['pending', 'rejected']);
  assert.deepEqual(steps('reversal'), ['pending', 'validated', 'reversed']);
  assert.deepEqual(steps('duplicate'), ['pending', 'pending', 'validated', 'validated']);
  assert.deepEqual(steps('unattributable'), ['pending', 'validated']);
  assert.ok(SCENARIOS.unattributable.steps.every((s) => s.sub === 'unknown-subid-000'));
  for (const s of Object.values(SCENARIOS)) for (const x of s.steps) assert.ok(STATUSES.includes(x.status));
});

test('transaction ids are unique enough and prefixed', () => {
  const ids = new Set(Array.from({ length: 200 }, () => newTransactionId()));
  assert.equal(ids.size, 200);
  for (const id of ids) assert.match(id, /^SIM-[0-9A-Z]+$/);
});

test('input validation gives plain messages', () => {
  assert.throws(() => validateInput({}), (e) => e instanceof InputError && /subid/.test(e.message));
  assert.throws(() => validateInput({ subId: 'a', commission: 'abc' }), /commission/);
  assert.throws(() => validateInput({ subId: 'a', commission: -1 }), /commission/);
  assert.throws(() => validateInput({ subId: 'a', saleAmount: 1e9 }), /sale amount/);
  const ok = validateInput({ subId: ' abc ', commission: '400.456' });
  assert.equal(ok.subId, 'abc');
  assert.equal(ok.commission, 400.46);
  assert.match(ok.transactionId, /^SIM-/);
  assert.equal(validateInput({ subId: 'a', transactionId: 'MINE' }).transactionId, 'MINE');
});

test('expected cashback is commission times share, to the paisa', () => {
  assert.equal(expectedCashback(1200, 50), 600);
  assert.equal(expectedCashback(333.33, 45), 150);
  assert.equal(expectedCashback(100, 0), 0);
});

test('only local targets are allowed unless remote is explicitly allowed', () => {
  assert.equal(checkTarget('https://localhost:7056').ok, true);
  assert.equal(checkTarget('http://127.0.0.1:5000').ok, true);
  assert.equal(checkTarget('http://[::1]:5000').ok, true);
  assert.equal(checkTarget('https://api.example.com').ok, false);
  assert.match(checkTarget('https://api.example.com').reason, /not a local address/);
  assert.equal(checkTarget('https://api.example.com', true).ok, true);
  assert.equal(checkTarget('https://api.example.com', true).local, false);
  assert.equal(checkTarget('ftp://localhost').ok, false);
  assert.equal(checkTarget('not a url').ok, false);
  assert.equal(checkTarget('https://localhost.evil.com').ok, false);
});

test('config reads the environment', () => {
  const c = readConfig({ SM_SIM_TARGET: 'http://localhost:1234/', SM_WEBHOOK_TOKEN: 't', SM_SIM_PORT: '9' });
  assert.deepEqual(c, { target: 'http://localhost:1234', token: 't', allowRemote: false, port: 9 });
  assert.equal(readConfig({}).target, 'https://localhost:7056');
});

// ---- the server, against a fake Smart Money API

async function withServer(config, fakeResponder, fn) {
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, headers: init.headers, body: JSON.parse(init.body) });
    const r = fakeResponder(calls.length, JSON.parse(init.body));
    if (r instanceof Error) throw r;
    return { status: r.status, text: async () => JSON.stringify(r.body) };
  };
  const server = http.createServer(createHandler({ fetchImpl, config }));
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${server.address().port}`;
  try { await fn({ base, calls }); } finally { await new Promise((r) => server.close(r)); }
}
const cfg = (over = {}) => ({ target: 'https://localhost:7056', token: 'secret-token', allowRemote: false, ...over });
const ok = (n, body) => ({ status: 200, body: { received: true, outcome: n === 1 ? 'Created' : 'Updated' } });
const post = (base, p, body, headers = {}) => fetch(base + p, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) });

test('config endpoint never reveals the token', async () => {
  await withServer(cfg(), ok, async ({ base }) => {
    const text = await (await fetch(base + '/api/config')).text();
    assert.ok(!text.includes('secret-token'));
    const c = JSON.parse(text);
    assert.equal(c.tokenSet, true);
    assert.equal(c.targetOk, true);
    assert.equal(c.scenarios.length, 5);
  });
});

test('a scenario posts each step in order with the token header', async () => {
  await withServer(cfg(), ok, async ({ base, calls }) => {
    const res = await post(base, '/api/scenario', { scenario: 'happy-path', subId: 'abc', commission: 400 });
    const data = await res.json();
    assert.equal(res.status, 200);
    assert.deepEqual(calls.map((c) => c.body.status), ['pending', 'validated', 'paid']);
    assert.ok(calls.every((c) => c.url === 'https://localhost:7056/api/webhooks/cuelinks'));
    assert.ok(calls.every((c) => c.headers['X-Webhook-Token'] === 'secret-token'));
    assert.equal(new Set(calls.map((c) => c.body.transaction_id)).size, 1); // one sale throughout
    assert.equal(calls[0].body.commission, 400);
    assert.deepEqual(data.results.map((r) => r.outcome), ['Created', 'Updated', 'Updated']);
    assert.equal(data.transactionId, calls[0].body.transaction_id);
  });
});

test('the unattributable scenario swaps in the unknown sub_id', async () => {
  await withServer(cfg(), ok, async ({ base, calls }) => {
    await post(base, '/api/scenario', { scenario: 'unattributable', subId: 'real-one' });
    assert.ok(calls.every((c) => c.body.sub_id === 'unknown-subid-000'));
  });
});

test('a custom step reuses the given transaction id', async () => {
  await withServer(cfg(), ok, async ({ base, calls }) => {
    await post(base, '/api/postback', { subId: 'abc', status: 'validated', transactionId: 'SIM-KEEP' });
    await post(base, '/api/postback', { subId: 'abc', status: 'paid', transactionId: 'SIM-KEEP' });
    assert.deepEqual(calls.map((c) => c.body.transaction_id), ['SIM-KEEP', 'SIM-KEEP']);
  });
});

test('a scenario stops at the first failing step', async () => {
  await withServer(cfg(), (n) => (n === 2 ? { status: 401, body: { message: 'no' } } : { status: 200, body: { outcome: 'Created' } }), async ({ base, calls }) => {
    const data = await (await post(base, '/api/scenario', { scenario: 'happy-path', subId: 'abc' })).json();
    assert.equal(calls.length, 2);
    assert.deepEqual(data.results.map((r) => r.httpStatus), [200, 401]);
  });
});

test('an unreachable API is reported, not thrown', async () => {
  await withServer(cfg(), () => Object.assign(new Error('fetch failed'), { cause: { code: 'ECONNREFUSED' } }), async ({ base }) => {
    const data = await (await post(base, '/api/postback', { subId: 'abc', status: 'pending' })).json();
    assert.equal(data.results[0].httpStatus, 0);
    assert.match(data.results[0].response, /ECONNREFUSED/);
  });
});

test('bad input is a 400 with a plain message and nothing is sent', async () => {
  await withServer(cfg(), ok, async ({ base, calls }) => {
    let r = await post(base, '/api/postback', { status: 'pending' });
    assert.equal(r.status, 400); assert.match((await r.json()).message, /subid/);
    r = await post(base, '/api/postback', { subId: 'a', status: 'bogus' });
    assert.equal(r.status, 400);
    r = await post(base, '/api/scenario', { scenario: 'nope', subId: 'a' });
    assert.equal(r.status, 400);
    r = await fetch(base + '/api/postback', { method: 'POST', body: '{not json' });
    assert.equal(r.status, 400);
    assert.equal(calls.length, 0);
  });
});

test('sending is refused without a token or for a non-local target', async () => {
  await withServer(cfg({ token: '' }), ok, async ({ base, calls }) => {
    const r = await post(base, '/api/postback', { subId: 'a', status: 'pending' });
    assert.equal(r.status, 400); assert.match((await r.json()).message, /SM_WEBHOOK_TOKEN/);
    assert.equal(calls.length, 0);
  });
  await withServer(cfg({ target: 'https://api.example.com' }), ok, async ({ base, calls }) => {
    const r = await post(base, '/api/scenario', { scenario: 'happy-path', subId: 'a' });
    assert.equal(r.status, 400); assert.match((await r.json()).message, /not a local address/);
    assert.equal(calls.length, 0);
    const c = await (await fetch(base + '/api/config')).json();
    assert.equal(c.targetOk, false);
  });
});

test('a foreign origin cannot drive the tool', async () => {
  await withServer(cfg(), ok, async ({ base, calls }) => {
    const r = await post(base, '/api/postback', { subId: 'a', status: 'pending' }, { Origin: 'https://evil.example' });
    assert.equal(r.status, 403);
    assert.equal(calls.length, 0);
    const local = await post(base, '/api/postback', { subId: 'a', status: 'pending' }, { Origin: 'http://localhost:5290' });
    assert.equal(local.status, 200);
  });
});

test('static files cannot escape the public folder', async () => {
  await withServer(cfg(), ok, async ({ base }) => {
    const r = await fetch(base + '/..%2f..%2fserver.mjs');
    assert.ok(r.status === 403 || r.status === 404);
    assert.ok(!(await r.text()).includes('createHandler'));
  });
});

// ---- step 3: create a tracked click

import { extractSubId, validateClickInput } from './postback.mjs';

test('subid is read from a merchant URL', () => {
  assert.equal(extractSubId('https://www.myntra.com/?subid=abc123'), 'abc123');
  assert.equal(extractSubId('https://x.test/?a=1&sub_id=zz9'), 'zz9');
  assert.equal(extractSubId('https://x.test/?subid='), null);
  assert.equal(extractSubId('https://x.test/'), null);
  assert.equal(extractSubId('not a url'), null);
  assert.equal(extractSubId(''), null);
});

test('click form validation', () => {
  const store = '11111111-1111-1111-1111-111111111111';
  assert.throws(() => validateClickInput({ password: 'p', storeId: store }), /email/);
  assert.throws(() => validateClickInput({ email: 'a@b.c', storeId: store }), /password/);
  assert.throws(() => validateClickInput({ email: 'a@b.c', password: 'p', storeId: 'x' }), /store/i);
  assert.deepEqual(validateClickInput({ email: ' a@b.c ', password: ' p ', storeId: store }), { email: 'a@b.c', password: ' p ', storeId: store });
});

const STORE = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

/** A fake Smart Money API: login, stores, clicks and the tracked redirect. */
function fakeApi(over = {}) {
  const seen = [];
  const reply = (status, body, headers = {}) => ({ status, text: async () => (body === undefined ? '' : JSON.stringify(body)), headers: { get: (k) => headers[k.toLowerCase()] ?? null } });
  const fetchImpl = async (url, init = {}) => {
    const p = new URL(url).pathname;
    seen.push({ path: p, method: init.method ?? 'GET', auth: init.headers?.Authorization, body: init.body ? JSON.parse(init.body) : undefined, redirect: init.redirect });
    if (over.down) throw Object.assign(new Error('fetch failed'), { cause: { code: 'ECONNREFUSED' } });
    if (p === '/api/stores') return over.stores ?? reply(200, [{ id: STORE, name: 'Myntra', slug: 'myntra', logoUrl: 'x' }]);
    if (p === '/api/identity/login') return over.login ?? reply(200, { accessToken: 'AT-1', userId: 'u1' });
    if (p === '/api/affiliate/clicks') return over.click ?? reply(200, { clickId: 'c1', redirectToken: 't', redirectPath: '/r/t' });
    if (p === '/r/t') return over.redirect ?? reply(302, undefined, { location: 'https://www.myntra.com/?subid=SUB-777' });
    throw new Error('unexpected ' + p);
  };
  return { fetchImpl, seen };
}
async function withApi(api, fn, config = cfg()) {
  const server = http.createServer(createHandler({ fetchImpl: api.fetchImpl, config }));
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  try { await fn(`http://127.0.0.1:${server.address().port}`); } finally { await new Promise((r) => server.close(r)); }
}
const clickBody = { email: 'u@x.test', password: 'Pw@12345', storeId: STORE };

test('stores are listed with only id, name and slug', async () => {
  await withApi(fakeApi(), async (base) => {
    const d = await (await fetch(base + '/api/stores')).json();
    assert.deepEqual(d.stores, [{ id: STORE, name: 'Myntra', slug: 'myntra' }]);
  });
});

test('create click signs in, clicks, follows the redirect and returns the subid', async () => {
  const api = fakeApi();
  await withApi(api, async (base) => {
    const res = await post(base, '/api/click', clickBody);
    const d = await res.json();
    assert.equal(res.status, 200);
    assert.equal(d.subId, 'SUB-777');
    assert.equal(d.merchant, 'https://www.myntra.com');
    assert.equal(d.userEmail, 'u@x.test');
    assert.deepEqual(api.seen.map((s) => s.path), ['/api/identity/login', '/api/affiliate/clicks', '/r/t']);
    assert.equal(api.seen[1].auth, 'Bearer AT-1');
    assert.deepEqual(api.seen[1].body, { storeId: STORE, offerId: null });
    assert.equal(api.seen[2].redirect, 'manual'); // never leaves the API
    assert.ok(!JSON.stringify(d).includes('Pw@12345'));
    assert.ok(!JSON.stringify(d).includes('AT-1'));
  });
});

test('create click explains each failure in plain words', async () => {
  const cases = [
    [{ login: { status: 401, text: async () => JSON.stringify({ message: 'Invalid email or password.' }), headers: { get: () => null } } }, /Invalid email or password/],
    [{ click: { status: 404, text: async () => '{}', headers: { get: () => null } } }, /no active affiliate mapping/],
    [{ redirect: { status: 302, text: async () => '', headers: { get: () => 'https://m.test/' } } }, /did not carry a subid/],
    [{ down: true }, /ECONNREFUSED/],
  ];
  for (const [over, message] of cases) {
    await withApi(fakeApi(over), async (base) => {
      const res = await post(base, '/api/click', clickBody);
      assert.equal(res.status, 400);
      assert.match((await res.json()).message, message);
    });
  }
});

test('create click rejects bad input before calling the API', async () => {
  const api = fakeApi();
  await withApi(api, async (base) => {
    const res = await post(base, '/api/click', { email: '', password: 'x', storeId: STORE });
    assert.equal(res.status, 400);
    assert.equal(api.seen.length, 0);
  });
});

test('click and stores refuse a non-local target', async () => {
  const api = fakeApi();
  await withApi(api, async (base) => {
    assert.equal((await post(base, '/api/click', clickBody)).status, 400);
    assert.equal((await fetch(base + '/api/stores')).status, 400);
    assert.equal(api.seen.length, 0);
  }, cfg({ target: 'https://api.example.com' }));
});
