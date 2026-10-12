// Local web tool that plays the role of Cuelinks. It forwards simulated
// Transaction Update postbacks to the Smart Money webhook. The webhook token
// stays here, on the server side; the browser never sees it.
//
//   set SM_WEBHOOK_TOKEN=<Webhooks:CuelinksToken>   (cmd)   or $env:SM_WEBHOOK_TOKEN (PowerShell)
//   node tools/affiliate-simulator/ui/server.mjs     (from backend/)
//
// Optional: SM_SIM_TARGET (default https://localhost:7056), SM_SIM_PORT
// (default 5290), SM_SIM_ALLOW_REMOTE=1 to allow a non-local target.
// It listens on 127.0.0.1 only.

import http from 'node:http';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { SCENARIOS, STATUSES, InputError, buildPostback, checkTarget, extractSubId, validateClickInput, validateInput } from './postback.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const MAX_BODY = 10_000;

/** Builds the HTTP request handler. `fetchImpl` and `config` are injectable for tests. */
export function createHandler({ fetchImpl = fetch, config }) {
  const target = checkTarget(config.target, config.allowRemote);

  async function sendPostback(fields, step = 1) {
    const body = buildPostback({ ...fields });
    const started = Date.now();
    try {
      const res = await fetchImpl(`${target.origin}/api/webhooks/cuelinks`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Webhook-Token': config.token },
        body: JSON.stringify(body),
      });
      const text = await res.text();
      let json = null;
      try { json = text ? JSON.parse(text) : null; } catch { /* keep the text */ }
      return { step, status: body.status, sub_id: body.sub_id, httpStatus: res.status, outcome: json?.outcome ?? null, response: json ?? text, request: body, ms: Date.now() - started };
    } catch (error) {
      return { step, status: body.status, sub_id: body.sub_id, httpStatus: 0, outcome: null, response: `Could not reach ${target.origin}: ${error.cause?.code ?? error.message}`, request: body, ms: Date.now() - started };
    }
  }

  /** Calls the Smart Money API; network failures become a plain message. */
  async function callApi(route, init = {}) {
    try {
      const res = await fetchImpl(`${target.origin}${route}`, init);
      const text = await res.text();
      let json = null;
      try { json = text ? JSON.parse(text) : null; } catch { /* not JSON */ }
      return { status: res.status, ok: res.status >= 200 && res.status < 300, json, headers: res.headers };
    } catch (error) {
      throw new InputError(`Could not reach ${target.origin}: ${error.cause?.code ?? error.message}`);
    }
  }

  /**
   * Does what the mobile app does when a user taps Earn Cashback: signs in as
   * the test user, creates a tracked click, follows the redirect without
   * leaving the API and reads the subid from the merchant URL. The password is
   * used once and never stored or logged.
   */
  async function createClick(input) {
    const { email, password, storeId } = validateClickInput(input);
    const login = await callApi('/api/identity/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
    if (!login.ok || !login.json?.accessToken) throw new InputError(login.json?.message ?? `Sign-in failed (HTTP ${login.status}).`);

    const click = await callApi('/api/affiliate/clicks', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${login.json.accessToken}` },
      body: JSON.stringify({ storeId, offerId: null }),
    });
    if (click.status === 404) throw new InputError('Cashback tracking is not available for that store (no active affiliate mapping). Choose one that is mapped in the admin app.');
    if (!click.ok || !click.json?.redirectPath) throw new InputError(click.json?.message ?? `Creating the click failed (HTTP ${click.status}).`);

    const redirect = await callApi(click.json.redirectPath, { redirect: 'manual' });
    const location = redirect.headers?.get?.('location') ?? '';
    const subId = extractSubId(location);
    if (!subId) throw new InputError('The redirect did not carry a subid, so a sale could not be attributed to this click.');
    let merchant = '';
    try { merchant = new URL(location).origin; } catch { /* leave blank */ }
    return { subId, clickId: click.json.clickId, merchant, userEmail: email };
  }

  async function handle(req, res) {
    const url = new URL(req.url, 'http://localhost');
    const send = (code, data) => { res.writeHead(code, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(data)); };

    // Only pages and scripts from this very tool may call it.
    const origin = req.headers.origin;
    if (origin && !/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) return send(403, { message: 'Forbidden origin.' });

    if (req.method === 'GET' && url.pathname === '/api/config') {
      return send(200, {
        target: config.target,
        targetOk: target.ok,
        targetLocal: target.local ?? false,
        targetProblem: target.ok ? null : target.reason,
        tokenSet: Boolean(config.token),
        statuses: STATUSES,
        scenarios: Object.entries(SCENARIOS).map(([key, s]) => ({ key, label: s.label, help: s.help, steps: s.steps.map((x) => x.status) })),
      });
    }

    if (req.method === 'GET' && url.pathname === '/api/stores') {
      if (!target.ok) return send(400, { message: target.reason });
      try {
        const r = await callApi('/api/stores');
        if (!r.ok || !Array.isArray(r.json)) return send(502, { message: `Could not load stores (HTTP ${r.status}).` });
        return send(200, { stores: r.json.map((s) => ({ id: s.id, name: s.name, slug: s.slug })) });
      } catch (error) {
        return send(502, { message: error.message });
      }
    }

    if (req.method === 'POST' && url.pathname === '/api/click') {
      if (!target.ok) return send(400, { message: target.reason });
      let raw = '';
      for await (const chunk of req) { raw += chunk; if (raw.length > MAX_BODY) return send(413, { message: 'Request too large.' }); }
      let input;
      try { input = raw ? JSON.parse(raw) : {}; } catch { return send(400, { message: 'Malformed JSON.' }); }
      try {
        return send(200, await createClick(input));
      } catch (error) {
        if (error instanceof InputError) return send(400, { message: error.message });
        throw error;
      }
    }

    if (req.method === 'POST' && (url.pathname === '/api/postback' || url.pathname === '/api/scenario')) {
      if (!target.ok) return send(400, { message: target.reason });
      if (!config.token) return send(400, { message: 'SM_WEBHOOK_TOKEN is not set. Start the tool with the Webhooks:CuelinksToken value.' });

      let raw = '';
      for await (const chunk of req) { raw += chunk; if (raw.length > MAX_BODY) return send(413, { message: 'Request too large.' }); }
      let input;
      try { input = raw ? JSON.parse(raw) : {}; } catch { return send(400, { message: 'Malformed JSON.' }); }

      try {
        const base = validateInput(input);
        if (url.pathname === '/api/postback') {
          if (!STATUSES.includes(input.status)) throw new InputError(`Status must be one of: ${STATUSES.join(', ')}.`);
          return send(200, { transactionId: base.transactionId, results: [await sendPostback({ ...base, status: input.status })] });
        }
        const scenario = SCENARIOS[input.scenario];
        if (!scenario) throw new InputError(`Unknown scenario. Choose one of: ${Object.keys(SCENARIOS).join(', ')}.`);
        const results = [];
        let n = 0;
        for (const step of scenario.steps) {
          const result = await sendPostback({ ...base, subId: step.sub ?? base.subId, status: step.status }, ++n);
          results.push(result);
          if (result.httpStatus === 0 || result.httpStatus >= 400) break; // do not keep posting into a failure
        }
        return send(200, { transactionId: base.transactionId, results });
      } catch (error) {
        if (error instanceof InputError) return send(400, { message: error.message });
        throw error;
      }
    }

    if (req.method === 'GET') return serveStatic(url.pathname, res);
    send(404, { message: 'Not found.' });
  }

  return (req, res) => handle(req, res).catch((error) => { console.error(error); if (!res.headersSent) { res.writeHead(500, { 'Content-Type': 'application/json' }); } res.end(JSON.stringify({ message: 'Unexpected error.' })); });
}

const TYPES = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml' };

async function serveStatic(pathname, res) {
  const rel = pathname === '/' ? 'index.html' : pathname.replace(/^\/+/, '');
  const file = path.resolve(here, 'public', rel);
  if (!file.startsWith(path.resolve(here, 'public') + path.sep)) { res.writeHead(403); return res.end(); }
  try {
    const data = await readFile(file);
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(data);
  } catch {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ message: 'Not found.' }));
  }
}

export function readConfig(env = process.env) {
  return {
    target: (env.SM_SIM_TARGET ?? 'https://localhost:7056').replace(/\/+$/, ''),
    token: env.SM_WEBHOOK_TOKEN ?? '',
    allowRemote: env.SM_SIM_ALLOW_REMOTE === '1',
    port: Number(env.SM_SIM_PORT ?? 5290),
  };
}

// Run only when started directly, not when imported by the tests.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const config = readConfig();
  const target = checkTarget(config.target, config.allowRemote);
  if (!target.ok) { console.error(target.reason); process.exit(1); }
  // The local development certificate is self-signed.
  if (target.local) process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
  http.createServer(createHandler({ config })).listen(config.port, '127.0.0.1', () => {
    console.log(`Affiliate simulator on http://localhost:${config.port}  ->  ${target.origin}`);
    if (!config.token) console.log('Warning: SM_WEBHOOK_TOKEN is not set; sending is disabled until it is.');
  });
}
