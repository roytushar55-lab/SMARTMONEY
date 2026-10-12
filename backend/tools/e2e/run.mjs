// End-to-end run of the whole Smart Money money path through the real API:
//
//   sign up and verify -> admin sets the cashback share -> user taps Earn
//   Cashback -> the Cuelinks simulator reports the sale -> cashback = commission
//   x share -> admin confirms it -> it is available balance -> user withdraws
//   -> admin approves and marks it paid -> wallet and ledger add up.
//
// It starts the API itself with safe overrides (console OTP, email disabled,
// a throwaway super admin, a test webhook token), so your user secrets are
// never touched and no real email is sent. It runs against the database the
// API is configured for and leaves its throwaway accounts behind.
//
//   node tools/e2e/run.mjs            (from backend/)
//
// Exit code 0 when every check passed.

import { spawn, spawnSync } from 'node:child_process';
import { mkdirSync, createWriteStream } from 'node:fs';
import { setTimeout as sleep } from 'node:timers/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'; // the local dev certificate

const here = path.dirname(fileURLToPath(import.meta.url));
const backendDir = path.resolve(here, '..', '..');
const apiProject = path.join(backendDir, 'src', 'SmartMoney.Api');
const logDir = path.join(backendDir, 'logs');
// Not the usual 7056: the owner's own API is often running there, and this
// run must never talk to an instance with real email settings.
const PORT = Number(process.env.SM_E2E_PORT ?? 7156);
const BASE = `https://localhost:${PORT}`;

const runId = new Date().toISOString().replace(/[-:T.Z]/g, '').slice(0, 14);
const buildDir = path.join(os.tmpdir(), 'smartmoney-e2e', runId);
const USER = {
  email: `e2e-user-${runId}@example.com`,
  password: 'E2e@Pass12345',
  name: 'E2E Test User',
  phone: '9' + String(Date.now()).slice(-9),
};
const ADMIN = {
  email: `e2e-admin-${runId}@example.com`,
  password: 'E2e@Admin12345',
  name: 'E2E Test Admin',
  phone: '8' + String(Date.now()).slice(-9),
};
const WEBHOOK_TOKEN = `e2e-token-${runId}`;
const CONSENT_VERSION = '2026-10-05';
const FLAT_FEE = 10; // makes the fee maths visible: 10 + 18% tax = 11.80

// ---------------------------------------------------------------- checks

let passed = 0;
const failures = [];

function check(name, condition, detail) {
  if (condition) {
    passed++;
    console.log(`  ok   ${name}`);
  } else {
    failures.push({ name, detail });
    console.log(`  FAIL ${name}${detail === undefined ? '' : `: ${fmt(detail)}`}`);
  }
  return condition;
}

function fmt(value) {
  return typeof value === 'string' ? value : JSON.stringify(value);
}

function section(title) {
  console.log(`\n== ${title}`);
}

/** Stops the run: something the script cannot sensibly continue past. */
class Stuck extends Error {}

function near(a, b) {
  return Math.abs(Number(a) - Number(b)) < 0.005;
}

// ------------------------------------------------------------------- API

let api = null;
let apiLog = '';
let apiLogFile = null;

async function startApi() {
  mkdirSync(logDir, { recursive: true });
  const logPath = path.join(logDir, `e2e-api-${runId}.log`);
  apiLogFile ??= createWriteStream(logPath, { flags: 'a' });

  // Never adopt a stranger: if something already answers on our port it is
  // not the instance we configured, and it may send real email.
  try {
    await fetch(`${BASE}/api/categories`);
    throw new Stuck(
      `Something already listens on ${BASE}. Stop it or set SM_E2E_PORT to a free port.`,
    );
  } catch (error) {
    if (error instanceof Stuck) throw error;
  }

  // Run the DLL from our own build folder, so the owner's bin folder (which
  // may back a running instance) is never written to or locked.
  api = spawn(
    'dotnet',
    [path.join(buildDir, 'SmartMoney.Api.dll'), '--urls', BASE],
    {
      cwd: buildDir,
      env: {
        ...process.env,
        ASPNETCORE_ENVIRONMENT: 'Development',
        Email__Host: ' ',
        Email__Password: 'disabled-for-test',
        Seed__SuperAdminEmail: ADMIN.email,
        Webhooks__CuelinksToken: WEBHOOK_TOKEN,
        Payouts__Provider: 'Manual',
        Payouts__FlatFee: String(FLAT_FEE),
        Payouts__PercentFee: '0',
        RateLimiting__AuthRequestsPerMinute: '500',
        RateLimiting__OtpRequestsPerTenMinutes: '100',
        RateLimiting__WithdrawalRequestsPerTenMinutes: '500',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  );
  for (const stream of [api.stdout, api.stderr]) {
    stream.on('data', (chunk) => {
      apiLog += chunk.toString();
      apiLogFile.write(chunk);
    });
  }
  const exited = new Promise((resolve) => api.once('exit', resolve));

  const deadline = Date.now() + 120_000;
  while (Date.now() < deadline) {
    if (api.exitCode !== null) {
      throw new Stuck(`The API exited early (code ${api.exitCode}). See ${logPath}`);
    }
    try {
      const res = await fetch(`${BASE}/api/categories`);
      if (res.ok) return logPath;
    } catch {
      // not up yet
    }
    await sleep(1000);
  }
  await stopApi();
  await exited;
  throw new Stuck(`The API did not answer within 2 minutes. See ${logPath}`);
}

async function stopApi() {
  if (!api || api.exitCode !== null) return;
  const exited = new Promise((resolve) => api.once('exit', resolve));
  if (process.platform === 'win32') {
    spawnSync('taskkill', ['/PID', String(api.pid), '/T', '/F'], { stdio: 'ignore' });
  } else {
    api.kill('SIGTERM');
  }
  await Promise.race([exited, sleep(10_000)]);
}

async function restartApi() {
  await stopApi();
  await sleep(1500); // let the port go
  return startApi();
}

/** The last OTP the console sender printed for [email]. */
function otpFor(email) {
  const pattern = new RegExp(
    `Email:\\s*${email.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*\\r?\\n\\s*OTP:\\s*(\\d+)`,
    'gi',
  );
  let last = null;
  for (const match of apiLog.matchAll(pattern)) last = match[1];
  return last;
}

async function waitForOtp(email) {
  const deadline = Date.now() + 15_000;
  while (Date.now() < deadline) {
    const otp = otpFor(email);
    if (otp) return otp;
    await sleep(250);
  }
  return null;
}

// ------------------------------------------------------------------ HTTP

async function call(method, route, { token, body, headers, redirect } = {}) {
  const res = await fetch(`${BASE}${route}`, {
    method,
    redirect: redirect ?? 'follow',
    headers: {
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(headers ?? {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: res.status, json, text, headers: res.headers };
}

const get = (route, opts) => call('GET', route, opts);
const post = (route, body, opts) => call('POST', route, { ...opts, body });
const put = (route, body, opts) => call('PUT', route, { ...opts, body });

function expectStatus(res, status, what) {
  return check(`${what} -> ${status}`, res.status === status, {
    status: res.status,
    body: res.json ?? res.text.slice(0, 300),
  });
}

// ----------------------------------------------------------------- steps

async function registerAndVerify(account) {
  const res = await post('/api/identity/register', {
    fullName: account.name,
    email: account.email,
    phoneNumber: account.phone,
    password: account.password,
    ageConfirmed: true,
    termsAccepted: true,
    consentVersion: CONSENT_VERSION,
  });
  if (!expectStatus(res, 201, `register ${account.email}`)) {
    throw new Stuck(`Could not register ${account.email}`);
  }

  const otp = await waitForOtp(account.email);
  if (!check(`OTP printed to the console for ${account.email}`, otp !== null)) {
    throw new Stuck('No OTP appeared in the API log; is Email__Host really blank?');
  }

  const verify = await post('/api/identity/verify-email-otp', {
    email: account.email,
    otp,
  });
  if (!expectStatus(verify, 200, `verify ${account.email}`)) {
    throw new Stuck(`Could not verify ${account.email}`);
  }
}

async function login(account) {
  const res = await post('/api/identity/login', {
    email: account.email,
    password: account.password,
  });
  if (!expectStatus(res, 200, `login ${account.email}`)) {
    throw new Stuck(`Could not log in ${account.email}`);
  }
  return { token: res.json.accessToken, userId: res.json.userId };
}

async function wallet(token) {
  const res = await get('/api/wallet', { token });
  expectStatus(res, 200, 'GET /api/wallet');
  return res.json;
}

async function ledger(token) {
  const res = await get('/api/wallet/transactions?page=1&pageSize=50', { token });
  expectStatus(res, 200, 'GET /api/wallet/transactions');
  return res.json?.items ?? [];
}

async function postback(body) {
  return post('/api/webhooks/cuelinks', body, {
    headers: { 'X-Webhook-Token': WEBHOOK_TOKEN },
  });
}

async function main() {
  console.log(`Smart Money end-to-end run ${runId}`);
  console.log(`user ${USER.email}, admin ${ADMIN.email}`);

  section('0. Build and start the API');
  console.log(`  building into ${buildDir}`);
  const build = spawnSync(
    'dotnet',
    ['build', apiProject, '-c', 'Debug', '--nologo', '-v', 'q', '-o', buildDir],
    { cwd: backendDir, stdio: 'inherit' },
  );
  if (build.status !== 0) throw new Stuck('dotnet build failed');
  const logPath = await startApi();
  console.log(`  API up at ${BASE}; its output goes to ${logPath}`);
  check(
    'manual payout provider is active',
    /payout provider 'Manual'/i.test(apiLog),
  );

  section('1. Sign up a user and an admin');
  await registerAndVerify(USER);
  await registerAndVerify(ADMIN);
  const user = await login(USER);

  section('2. Restart so the admin is promoted, then log the admin in');
  await restartApi();
  const admin = await login(ADMIN);
  expectStatus(
    await get('/api/admin/withdrawals', { token: admin.token }),
    200,
    'admin can list withdrawals',
  );
  expectStatus(
    await get('/api/admin/withdrawals', { token: user.token }),
    403,
    'the user cannot',
  );
  expectStatus(await get('/api/admin/withdrawals'), 401, 'nobody without a token');

  section('3. Admin cashback settings for the Cuelinks network');
  const networks = await get('/api/admin/cashback-settings/networks', {
    token: admin.token,
  });
  expectStatus(networks, 200, 'list affiliate networks');
  const cuelinks = (networks.json ?? []).find(
    (n) => String(n.code).toUpperCase() === 'CUELINKS',
  );
  if (!check('a CUELINKS network exists', Boolean(cuelinks), networks.json)) {
    throw new Stuck('No Cuelinks network in the database (docs/database/affiliate-seed.sql).');
  }
  const settings = await get(`/api/admin/cashback-settings/networks/${cuelinks.id}`, {
    token: admin.token,
  });
  expectStatus(settings, 200, 'read network cashback settings');
  let share = Number(settings.json?.networkSettings?.userSharePercent ?? 0);
  if (share <= 0) {
    const updated = await put(
      `/api/admin/cashback-settings/networks/${cuelinks.id}`,
      { userSharePercent: 50, confirmationWindowDays: 30 },
      { token: admin.token },
    );
    expectStatus(updated, 200, 'set a 50% user share');
    share = 50;
  }
  console.log(`  user share of commission: ${share}%`);
  check('the share is a usable percentage', share > 0 && share <= 100, share);

  section('4. The user shops: a tracked click on a store with cashback');
  const stores = await get('/api/stores', { token: user.token });
  expectStatus(stores, 200, 'list stores');
  const ordered = [...(stores.json ?? [])].sort((a, b) =>
    (a.slug === 'myntra' ? -1 : 0) - (b.slug === 'myntra' ? -1 : 0),
  );
  let click = null;
  let store = null;
  for (const candidate of ordered) {
    const res = await post(
      '/api/affiliate/clicks',
      { storeId: candidate.id, offerId: null },
      { token: user.token },
    );
    if (res.status === 200) {
      click = res.json;
      store = candidate;
      break;
    }
  }
  if (!check('a store with an active affiliate mapping accepts a click', Boolean(click))) {
    throw new Stuck('No store accepts clicks; run docs/database/affiliate-seed.sql first.');
  }
  console.log(`  store: ${store.name} (${store.slug})`);
  const redirect = await get(`/r/${click.redirectToken}`, { redirect: 'manual' });
  check('the redirect answers with a 3xx', redirect.status >= 300 && redirect.status < 400, redirect.status);
  const location = redirect.headers.get('location') ?? '';
  const subId = (() => {
    try {
      return new URL(location).searchParams.get('subid');
    } catch {
      return null;
    }
  })();
  if (!check('the merchant URL carries subid (the tracking reference)', Boolean(subId), location)) {
    throw new Stuck('No subid on the redirect; cannot attribute the sale.');
  }

  section('5. The affiliate network reports the sale (simulator)');
  // Enough commission that the user can withdraw twice at the minimum.
  const commission = Math.max(1000, Math.ceil(60000 / share));
  const expectedCashback = Math.round((commission * share) / 100 * 100) / 100;
  const transactionId = `E2E-${runId}`;
  const update = (status) => ({
    transaction_id: transactionId,
    campaign_id: 'E2E-CAMPAIGN',
    sub_id: subId,
    status,
    sale_amount: commission * 10,
    commission,
    currency: 'INR',
    transaction_date: new Date(Date.now() - 7_200_000).toISOString(),
    updated_at: new Date().toISOString(),
  });
  expectStatus(
    await post('/api/webhooks/cuelinks', update('pending'), {
      headers: { 'X-Webhook-Token': 'wrong-token' },
    }),
    401,
    'a wrong webhook token is refused',
  );
  const pending = await postback(update('pending'));
  expectStatus(pending, 200, 'postback: pending');
  console.log(`  outcome: ${pending.json?.outcome}`);

  let mine = await get('/api/cashbacks', { token: user.token });
  expectStatus(mine, 200, 'user lists cashbacks');
  let items = mine.json?.items ?? mine.json ?? [];
  check('one cashback was created', items.length === 1, items);
  const cashback = items[0] ?? {};
  check(
    `cashback = commission ${commission} x ${share}% = ${expectedCashback}`,
    near(cashback.cashbackAmount, expectedCashback),
    cashback,
  );
  check('it is Pending', cashback.status === 'Pending', cashback.status);
  let w = await wallet(user.token);
  check('wallet: pending balance = cashback', near(w.pendingBalance, expectedCashback), w);
  check('wallet: nothing available yet', near(w.availableBalance, 0), w);

  expectStatus(await postback(update('pending')), 200, 'postback: pending again (duplicate)');
  expectStatus(await postback(update('validated')), 200, 'postback: validated');
  expectStatus(await postback(update('paid')), 200, 'postback: paid (network settlement)');
  mine = await get('/api/cashbacks', { token: user.token });
  items = mine.json?.items ?? mine.json ?? [];
  check('still exactly one cashback after replays', items.length === 1, items.length);
  check(
    'validated parks it for admin review, paid does not touch it',
    items[0]?.status === 'AwaitingAdminReview',
    items[0]?.status,
  );

  section('6. Admin confirms the cashback');
  const review = await get(
    '/api/admin/cashbacks?status=AwaitingAdminReview&page=1&pageSize=100',
    { token: admin.token },
  );
  expectStatus(review, 200, 'admin lists cashbacks under review');
  const toApprove = (review.json?.items ?? []).find((c) => c.userId === user.userId);
  if (!check('the user cashback is in the review queue', Boolean(toApprove))) {
    throw new Stuck('Cashback missing from the admin review queue.');
  }
  check('it shows the store and the commission', toApprove.storeName === store.name && near(toApprove.commissionAmount, commission), toApprove);
  const approved = await post(`/api/admin/cashbacks/${toApprove.id}/approve`, undefined, {
    token: admin.token,
  });
  expectStatus(approved, 200, 'approve');
  check('approve answers Confirmed', approved.json?.status === 'Confirmed', approved.json);
  check('approve answers the new available balance', near(approved.json?.availableBalance, expectedCashback), approved.json);
  w = await wallet(user.token);
  check('wallet: available = cashback', near(w.availableBalance, expectedCashback), w);
  check('wallet: pending back to 0', near(w.pendingBalance, 0), w);
  check('wallet: total earned = cashback', near(w.totalEarned, expectedCashback), w);
  check('wallet: nothing held', near(w.heldBalance, 0), w);
  let entries = await ledger(user.token);
  check(
    'ledger has CashbackPending and CashbackConfirmed',
    ['CashbackPending', 'CashbackConfirmed'].every((t) => entries.some((e) => e.type === t)),
    entries.map((e) => e.type),
  );

  section('7. The user withdraws (manual provider: admin pays and records it)');
  const amount = 250;
  const feeTotal = Math.round(FLAT_FEE * 1.18 * 100) / 100; // 11.80
  const userFee = Math.round((feeTotal / 2) * 100) / 100; // 5.90
  const net = Math.round((amount - userFee) * 100) / 100;
  const tooSmall = await get('/api/withdrawals/preview?amount=100', { token: user.token });
  expectStatus(tooSmall, 200, 'preview 100');
  check('preview 100: not allowed, says why', tooSmall.json?.canWithdraw === false && /250/.test(tooSmall.json?.message ?? ''), tooSmall.json);
  const preview = await get(`/api/withdrawals/preview?amount=${amount}`, { token: user.token });
  expectStatus(preview, 200, `preview ${amount}`);
  check(`preview ${amount}: allowed, fee ${feeTotal}, user pays ${userFee}, net ${net}`,
    preview.json?.canWithdraw === true && near(preview.json.feeTotal, feeTotal) && near(preview.json.userFee, userFee) && near(preview.json.netAmount, net),
    preview.json);

  const requestBody = {
    amount,
    method: 'Upi',
    // Letters only: the server refuses digits in an account holder's name.
    beneficiaryName: 'Test User',
    upiId: 'e2euser@okhdfc',
    password: USER.password,
  };
  // The database also holds earlier runs, so every summary check is a change from "before".
  const wdSummary = async () => (await get('/api/admin/withdrawals/summary', { token: admin.token })).json ?? {};
  const wdRows = async (query) => (await get(`/api/admin/withdrawals?page=1&pageSize=100&${query}`, { token: admin.token })).json?.items ?? [];
  const wdBefore = await wdSummary();
  const wrongPassword = await post('/api/withdrawals', { ...requestBody, password: 'nope' }, { token: user.token });
  expectStatus(wrongPassword, 400, 'request with a wrong password');
  const requested = await post('/api/withdrawals', requestBody, { token: user.token });
  if (!expectStatus(requested, 201, 'request the withdrawal')) {
    throw new Stuck('Withdrawal request refused.');
  }
  const wd = requested.json;
  check('it is Requested and cancellable', wd.status === 'Requested' && wd.canCancel === true, wd);
  check('the destination is masked', wd.destination !== 'e2euser@okhdfc' && /\*/.test(wd.destination), wd.destination);
  check('it has a reference like WD...', /^WD[A-Z0-9]{10,}$/.test(wd.reference ?? ''), wd.reference);
  w = await wallet(user.token);
  check('wallet: amount moved from available to held', near(w.availableBalance, expectedCashback - amount) && near(w.heldBalance, amount), w);
  expectStatus(await post('/api/withdrawals', requestBody, { token: user.token }), 409, 'a second open withdrawal');

  const adminList = await get('/api/admin/withdrawals?status=Requested&page=1&pageSize=100', { token: admin.token });
  expectStatus(adminList, 200, 'admin lists requested withdrawals');
  const listed = (adminList.json?.items ?? []).find((x) => x.id === wd.id);
  check(
    'admin sees it with the user email and only a masked destination',
    listed?.userEmail === USER.email &&
      listed?.destination == null &&
      /\*/.test(listed?.destinationMasked ?? ''),
    listed,
  );
  const adminDetail = await get(`/api/admin/withdrawals/${wd.id}`, { token: admin.token });
  expectStatus(adminDetail, 200, 'admin opens it');
  check('admin detail carries the full UPI ID to pay', adminDetail.json?.destination?.upiId === 'e2euser@okhdfc', adminDetail.json?.destination);
  check('admin detail is not cacheable', /no-store/.test(adminDetail.headers.get('cache-control') ?? ''), adminDetail.headers.get('cache-control'));

  const wdRequested = await wdSummary();
  check('summary: to decide went up by one, by the payout amount', wdRequested.toDecide === wdBefore.toDecide + 1 && near(wdRequested.toDecideAmount, wdBefore.toDecideAmount + net), { wdBefore, wdRequested });
  const inQueue = (await wdRows('queue=ToDecide')).find((x) => x.id === wd.id);
  check('it is in the To decide queue, and the row says so', inQueue?.queue === 'ToDecide', inQueue);
  check('search finds it by our reference, in any case', (await wdRows(`search=${encodeURIComponent(wd.reference.toLowerCase())}`)).some((x) => x.id === wd.id));
  check('search finds it by the user name', (await wdRows(`search=${encodeURIComponent('test user')}`)).some((x) => x.id === wd.id));
  check('search finds it by the payout amount', (await wdRows(`search=${net}`)).some((x) => x.id === wd.id), net);
  check('the old status filter still finds it', (await wdRows('status=Requested')).some((x) => x.id === wd.id));
  check('it is not in the To pay queue yet', !(await wdRows('queue=ToPay')).some((x) => x.id === wd.id));
  expectStatus(await get('/api/admin/withdrawals?queue=Nope', { token: admin.token }), 400, 'an unknown withdrawal queue');
  expectStatus(await get('/api/admin/withdrawals/summary', { token: user.token }), 403, 'withdrawals summary as a normal user');
  expectStatus(await get('/api/admin/withdrawals/summary'), 401, 'withdrawals summary with no token');

  const approveWd = await post(`/api/admin/withdrawals/${wd.id}/approve`, undefined, { token: admin.token });
  expectStatus(approveWd, 200, 'admin approves');
  check('status Approved', approveWd.json?.status === 'Approved', approveWd.json);
  const wdApproved = await wdSummary();
  check('summary: moved from to decide to to pay', wdApproved.toDecide === wdBefore.toDecide && wdApproved.toPay === wdBefore.toPay + 1 && near(wdApproved.toPayAmount, wdBefore.toPayAmount + net), { wdBefore, wdApproved });
  check('it is now in the To pay queue', (await wdRows('queue=ToPay')).some((x) => x.id === wd.id && x.queue === 'ToPay'));
  expectStatus(await post(`/api/withdrawals/${wd.id}/cancel`, undefined, { token: user.token }), 409, 'user can no longer cancel');
  const paid = await post(`/api/admin/withdrawals/${wd.id}/mark-paid`, { transactionReference: `UTR${runId}` }, { token: admin.token });
  expectStatus(paid, 200, 'admin marks it paid');
  check('status Completed', paid.json?.status === 'Completed', paid.json);
  const wdPaid = await wdSummary();
  check('summary: to pay is back, paid in 30 days went up by one, by the payout amount', wdPaid.toPay === wdBefore.toPay && wdPaid.paidLast30Days === wdBefore.paidLast30Days + 1 && near(wdPaid.paidLast30DaysAmount, wdBefore.paidLast30DaysAmount + net), { wdBefore, wdPaid });
  check('history grew by one', wdPaid.history === wdBefore.history + 1, { before: wdBefore.history, after: wdPaid.history });
  check('it is in History', (await wdRows('queue=History')).some((x) => x.id === wd.id && x.queue === 'History'));
  check('search finds it by the bank reference (UTR)', (await wdRows(`search=${encodeURIComponent(`utr${runId}`)}`)).some((x) => x.id === wd.id));
  const todayStart = new Date(); todayStart.setHours(0, 0, 0, 0);
  const tomorrowStart = new Date(todayStart.getTime() + 86_400_000);
  check('a date range for today finds it', (await wdRows(`from=${encodeURIComponent(todayStart.toISOString())}&to=${encodeURIComponent(tomorrowStart.toISOString())}`)).some((x) => x.id === wd.id));
  check('a range in the future does not', !(await wdRows('from=2099-01-01T00:00:00Z')).some((x) => x.id === wd.id));

  const userView = await get(`/api/withdrawals/${wd.id}`, { token: user.token });
  expectStatus(userView, 200, 'user opens it');
  check('user sees Paid with the bank reference', userView.json?.status === 'Completed' && userView.json?.transactionReference === `UTR${runId}` && userView.json?.canCancel === false, userView.json);
  const settledDetail = await get(`/api/admin/withdrawals/${wd.id}`, { token: admin.token });
  check('bank details are wiped once settled', settledDetail.json?.destination == null, settledDetail.json?.destination);
  w = await wallet(user.token);
  check('wallet: held back to 0', near(w.heldBalance, 0), w);
  check(`wallet: withdrawn = ${amount}`, near(w.totalWithdrawn, amount), w);
  check('wallet: available unchanged by the payout', near(w.availableBalance, expectedCashback - amount), w);

  section('8. A second request, cancelled by the user');
  const second = await post('/api/withdrawals', requestBody, { token: user.token });
  expectStatus(second, 201, 'request again');
  w = await wallet(user.token);
  check('wallet: held again', near(w.heldBalance, amount), w);
  const cancelled = await post(`/api/withdrawals/${second.json?.id}/cancel`, undefined, { token: user.token });
  expectStatus(cancelled, 200, 'cancel');
  check('cancel answers Cancelled with the money back', cancelled.json?.status === 'Cancelled' && near(cancelled.json?.heldBalance, 0) && near(cancelled.json?.availableBalance, expectedCashback - amount), cancelled.json);
  const wdCancelled = await wdSummary();
  check('a cancelled one is history, not paid: paid in 30 days unchanged', wdCancelled.history === wdBefore.history + 2 && wdCancelled.paidLast30Days === wdBefore.paidLast30Days + 1, { wdBefore, wdCancelled });
  check('it shows in History as Cancelled', (await wdRows(`queue=History&search=${encodeURIComponent('test user')}`)).some((x) => x.id === second.json?.id && x.status === 'Cancelled'));
  const history = await get('/api/withdrawals?page=1&pageSize=20', { token: user.token });
  expectStatus(history, 200, 'user lists withdrawals');
  const statuses = (history.json?.items ?? []).map((x) => x.status).sort();
  check('history shows one Paid and one Cancelled', JSON.stringify(statuses) === JSON.stringify(['Cancelled', 'Completed']), statuses);

  section('9. Everything adds up');
  w = await wallet(user.token);
  check(
    'available + held + withdrawn = earned',
    near(w.availableBalance + w.heldBalance + w.totalWithdrawn, w.totalEarned),
    w,
  );
  entries = await ledger(user.token);
  const types = entries.map((e) => e.type);
  check(
    'ledger: pending, confirmed, requested x2, completed, released',
    ['CashbackPending', 'CashbackConfirmed', 'WithdrawalCompleted', 'WithdrawalReleased'].every((t) => types.includes(t)) &&
      types.filter((t) => t === 'WithdrawalRequested').length === 2,
    types,
  );
  const newest = entries[0];
  check('newest ledger entry balances match the wallet', newest && near(newest.availableBalanceAfter, w.availableBalance) && near(newest.pendingBalanceAfter, w.pendingBalance), { newest, w });
  check('ledger never shows a negative balance', entries.every((e) => e.availableBalanceAfter >= 0 && e.pendingBalanceAfter >= 0), entries);

  section('10. The approval gate: no approving while the network says pending');
  // A fresh sale, left at "pending" by the network.
  const gateClick = await post('/api/affiliate/clicks', { storeId: store.id, offerId: null }, { token: user.token });
  const gateRedirect = await get(`/r/${gateClick.json?.redirectToken}`, { redirect: 'manual' });
  const gateSub = new URL(gateRedirect.headers.get('location')).searchParams.get('subid');
  const gateTx = `E2E-GATE-${runId}`;
  const gateUpdate = (status) => ({
    transaction_id: gateTx, campaign_id: 'E2E-CAMPAIGN', sub_id: gateSub, status,
    sale_amount: 8000, commission: 800, currency: 'INR',
    transaction_date: new Date(Date.now() - 7_200_000).toISOString(), updated_at: new Date().toISOString(),
  });
  expectStatus(await postback(gateUpdate('pending')), 200, 'postback: a second sale, pending');
  const pendingRows = await get('/api/admin/cashbacks?status=Pending&page=1&pageSize=100', { token: admin.token });
  const gated = (pendingRows.json?.items ?? []).find((c) => c.userId === user.userId && near(c.commissionAmount, 800));
  if (!check('the second sale is in the admin list as Pending', Boolean(gated))) {
    throw new Stuck('Second sale missing from the admin list.');
  }
  check('its network status reads pending', String(gated.networkStatus).toLowerCase() === 'pending', gated.networkStatus);
  const walletBeforeGate = await wallet(user.token);

  const refused = await post(`/api/admin/cashbacks/${gated.id}/approve`, undefined, { token: admin.token });
  expectStatus(refused, 409, 'approve while the network says pending');
  check('the refusal explains why in plain words', /pending/i.test(refused.json?.message ?? '') && /validated/i.test(refused.json?.message ?? ''), refused.json);
  const noReason = await post(`/api/admin/cashbacks/${gated.id}/approve`, { override: true }, { token: admin.token });
  expectStatus(noReason, 400, 'override without a reason');
  check('the money did not move', near((await wallet(user.token)).availableBalance, walletBeforeGate.availableBalance), await wallet(user.token));

  // A plain Admin (not a SuperAdmin) must not be able to override.
  const plain = await post(`/api/admin/users/${user.userId}/role`, { role: 'Admin' }, { token: admin.token });
  expectStatus(plain, 200, 'make the test user a plain Admin');
  const plainAdmin = await login(USER);
  const plainRefused = await post(`/api/admin/cashbacks/${gated.id}/approve`, undefined, { token: plainAdmin.token });
  expectStatus(plainRefused, 409, 'a plain Admin is refused too while pending');
  const plainOverride = await post(`/api/admin/cashbacks/${gated.id}/approve`, { override: true, reason: 'trying it' }, { token: plainAdmin.token });
  expectStatus(plainOverride, 403, 'a plain Admin cannot override');
  expectStatus(await post(`/api/admin/users/${user.userId}/role`, { role: 'Customer' }, { token: admin.token }), 200, 'put the test user back to Customer');

  const overridden = await post(`/api/admin/cashbacks/${gated.id}/approve`, { override: true, reason: 'E2E: merchant confirmed by email' }, { token: admin.token });
  expectStatus(overridden, 200, 'a SuperAdmin overrides with a reason');
  check('it is Confirmed and the money moved', overridden.json?.status === 'Confirmed' && near(overridden.json?.availableBalance, walletBeforeGate.availableBalance + (800 * share) / 100), overridden.json);

  const trail = await get(`/api/admin/cashbacks/${gated.id}/events`, { token: admin.token });
  expectStatus(trail, 200, 'read the audit trail');
  const trailTypes = (trail.json ?? []).map((e) => e.type);
  check('the trail shows Created then ApprovedByOverride', trailTypes[0] === 'Created' && trailTypes.at(-1) === 'ApprovedByOverride', trailTypes);
  const last = trail.json?.at(-1);
  check('the override records who, why and the network status', last?.actorEmail === ADMIN.email && last?.reason === 'E2E: merchant confirmed by email' && String(last?.networkStatus).toLowerCase() === 'pending', last);
  expectStatus(await get('/api/admin/cashbacks/00000000-0000-0000-0000-000000000000/events', { token: admin.token }), 404, 'trail of an unknown cashback');
  expectStatus(await get(`/api/admin/cashbacks/${gated.id}/events`, { token: user.token }), 403, 'trail as a normal user');

  section('11. The review queues and the summary');
  // The database also holds earlier runs, so every check is a change from "before".
  const summaryOf = async () => (await get('/api/admin/cashbacks/summary', { token: admin.token })).json ?? {};
  const queueRows = async (queue, search) => (await get(
    `/api/admin/cashbacks?queue=${queue}&page=1&pageSize=100${search ? `&search=${encodeURIComponent(search)}` : ''}`,
    { token: admin.token })).json?.items ?? [];

  const before = await summaryOf();
  const queueClick = await post('/api/affiliate/clicks', { storeId: store.id, offerId: null }, { token: user.token });
  const queueRedirect = await get(`/r/${queueClick.json?.redirectToken}`, { redirect: 'manual' });
  const queueSub = new URL(queueRedirect.headers.get('location')).searchParams.get('subid');
  const queueTx = `E2E-QUEUE-${runId}`;
  const queueUpdate = (status) => ({
    transaction_id: queueTx, campaign_id: 'E2E-CAMPAIGN', sub_id: queueSub, status,
    sale_amount: 6000, commission: 600, currency: 'INR',
    transaction_date: new Date(Date.now() - 7_200_000).toISOString(), updated_at: new Date().toISOString(),
  });
  const queueAmount = (600 * share) / 100;

  expectStatus(await postback(queueUpdate('pending')), 200, 'postback: a third sale, pending');
  const waitingRow = (await queueRows('WaitingOnNetwork', USER.email)).find((c) => near(c.commissionAmount, 600));
  check('a pending sale is in Waiting on network', Boolean(waitingRow) && waitingRow.queue === 'WaitingOnNetwork' && waitingRow.isOverdue === false, waitingRow);
  const afterPending = await summaryOf();
  check('the waiting count went up by one', afterPending.waitingOnNetwork === before.waitingOnNetwork + 1, { before: before.waitingOnNetwork, after: afterPending.waitingOnNetwork });

  expectStatus(await postback(queueUpdate('validated')), 200, 'postback: the same sale, validated');
  check('it left Waiting on network', !(await queueRows('WaitingOnNetwork', USER.email)).some((c) => near(c.commissionAmount, 600)));
  const readyRow = (await queueRows('ReadyToApprove', USER.email)).find((c) => near(c.commissionAmount, 600));
  check('it is now in Ready to approve', Boolean(readyRow) && readyRow.queue === 'ReadyToApprove', readyRow);
  const afterValidated = await summaryOf();
  check('ready and needs-a-decision each went up by one', afterValidated.readyToApprove === before.readyToApprove + 1 && afterValidated.needsDecision === before.needsDecision + 1, { before, afterValidated });
  check('waiting went back down', afterValidated.waitingOnNetwork === before.waitingOnNetwork, afterValidated);
  check('the old status filter still finds it', ((await get('/api/admin/cashbacks?status=AwaitingAdminReview&pageSize=100', { token: admin.token })).json?.items ?? []).some((c) => c.id === readyRow?.id));

  const bySearch = await queueRows('ReadyToApprove', String(readyRow?.userFullName ?? '').toUpperCase());
  check('search finds it by the user name in any case', bySearch.some((c) => c.id === readyRow?.id));
  const byAmount = await queueRows('ReadyToApprove', String(queueAmount));
  check('search finds it by the cashback amount', byAmount.some((c) => c.id === readyRow?.id), queueAmount);

  const exposureBefore = afterValidated.exposureAmount;
  expectStatus(await post(`/api/admin/cashbacks/${readyRow?.id}/approve`, undefined, { token: admin.token }), 200, 'approve the validated sale');
  check('it moved to History', (await queueRows('History', USER.email)).some((c) => c.id === readyRow?.id));
  const afterApprove = await summaryOf();
  check('ready went back down and history up by one', afterApprove.readyToApprove === before.readyToApprove && afterApprove.history === before.history + 1, { before, afterApprove });
  check('exposure grew by this cashback (confirmed, network not paid yet)', near(afterApprove.exposureAmount, exposureBefore + queueAmount), { exposureBefore, after: afterApprove.exposureAmount, queueAmount });

  expectStatus(await get('/api/admin/cashbacks?queue=Nope', { token: admin.token }), 400, 'an unknown queue name');
  expectStatus(await get('/api/admin/cashbacks/summary', { token: user.token }), 403, 'summary as a normal user');

  section('12. Reject and reverse need a reason');
  // A reversal: the sale approved in section 11, which the network now takes back.
  expectStatus(await postback(queueUpdate('reversed')), 200, 'postback: the approved sale, reversed');
  const reversalRow = (await queueRows('ReversalsToDecide', USER.email)).find((c) => c.id === readyRow?.id);
  check('it is in Reversals to decide', Boolean(reversalRow) && reversalRow.queue === 'ReversalsToDecide', reversalRow);
  const walletBeforeReverse = await wallet(user.token);
  const reverseUrl = `/api/admin/cashbacks/${readyRow?.id}/reverse`;
  expectStatus(await post(reverseUrl, undefined, { token: admin.token }), 400, 'reverse with no body');
  expectStatus(await post(reverseUrl, { reason: '   ' }, { token: admin.token }), 400, 'reverse with a blank reason');
  expectStatus(await post(reverseUrl, { reason: 'x'.repeat(501) }, { token: admin.token }), 400, 'reverse with a 501-character reason');
  check('nothing moved while it was refused', near((await wallet(user.token)).availableBalance, walletBeforeReverse.availableBalance));
  const reversed = await post(reverseUrl, { reason: '  E2E: network took it back  ' }, { token: admin.token });
  expectStatus(reversed, 200, 'reverse with a reason');
  check('the money was taken back', near(reversed.json?.availableBalance, walletBeforeReverse.availableBalance - queueAmount), reversed.json);
  const reverseTrail = (await get(`/api/admin/cashbacks/${readyRow?.id}/events`, { token: admin.token })).json ?? [];
  check('the trail keeps the reason, trimmed', reverseTrail.at(-1)?.type === 'Reversed' && reverseTrail.at(-1)?.reason === 'E2E: network took it back', reverseTrail.at(-1));

  // A rejection: a fresh sale the network has not answered on yet.
  const rejectClick = await post('/api/affiliate/clicks', { storeId: store.id, offerId: null }, { token: user.token });
  const rejectRedirect = await get(`/r/${rejectClick.json?.redirectToken}`, { redirect: 'manual' });
  const rejectSub = new URL(rejectRedirect.headers.get('location')).searchParams.get('subid');
  expectStatus(await postback({
    transaction_id: `E2E-REJECT-${runId}`, campaign_id: 'E2E-CAMPAIGN', sub_id: rejectSub, status: 'pending',
    sale_amount: 4000, commission: 400, currency: 'INR',
    transaction_date: new Date(Date.now() - 7_200_000).toISOString(), updated_at: new Date().toISOString(),
  }), 200, 'postback: a fifth sale, pending');
  const toReject = (await queueRows('WaitingOnNetwork', USER.email)).find((c) => near(c.commissionAmount, 400));
  if (!check('it waits on the network', Boolean(toReject))) throw new Stuck('Fifth sale missing.');
  const rejectUrl = `/api/admin/cashbacks/${toReject.id}/reject`;
  expectStatus(await post(rejectUrl, undefined, { token: admin.token }), 400, 'reject with no body');
  expectStatus(await post(rejectUrl, { reason: '' }, { token: admin.token }), 400, 'reject with an empty reason');
  check('it is still waiting', (await queueRows('WaitingOnNetwork', USER.email)).some((c) => c.id === toReject.id));
  expectStatus(await post(rejectUrl, { reason: 'E2E: order was returned' }, { token: admin.token }), 200, 'reject with a reason');
  const rejectTrail = (await get(`/api/admin/cashbacks/${toReject.id}/events`, { token: admin.token })).json ?? [];
  check('the trail keeps the reason and the admin', rejectTrail.at(-1)?.type === 'Rejected' && rejectTrail.at(-1)?.reason === 'E2E: order was returned' && rejectTrail.at(-1)?.actorEmail === ADMIN.email, rejectTrail.at(-1));
  expectStatus(await post(`/api/admin/cashbacks/${toReject.id}/reject`, { reason: 'again' }, { token: admin.token }), 409, 'rejecting it twice');
}

// ------------------------------------------------------------------- run

let exitCode = 0;
try {
  await main();
} catch (error) {
  exitCode = 2;
  if (error instanceof Stuck) {
    console.log(`\nSTOPPED: ${error.message}`);
  } else {
    console.log('\nSTOPPED by an unexpected error:');
    console.log(error);
  }
} finally {
  await stopApi();
  apiLogFile?.end();
}

console.log(`\n${passed} checks passed, ${failures.length} failed.`);
for (const f of failures) console.log(`  - ${f.name}${f.detail === undefined ? '' : `: ${fmt(f.detail)}`}`);
console.log(`Throwaway accounts left in the database: ${USER.email}, ${ADMIN.email}`);
process.exit(failures.length === 0 && exitCode === 0 ? 0 : exitCode || 1);
