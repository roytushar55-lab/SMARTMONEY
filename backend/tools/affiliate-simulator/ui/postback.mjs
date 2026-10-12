// Pure logic for the affiliate simulator: payload shapes, scenarios and the
// target safety rule. No network, no timers, so it can be unit tested.
//
// Field names mirror the publicly documented Cuelinks Transaction Update
// conventions, exactly as tools/affiliate-simulator/Send-Postback.ps1 sends
// them. Verify against a live Cuelinks account before pointing real postbacks
// at a real server.

export const STATUSES = ['pending', 'validated', 'paid', 'rejected', 'reversed'];

/** Same steps as Send-Postback.ps1, in order. `sub` overrides the sub_id. */
export const SCENARIOS = {
  'happy-path': {
    label: 'Happy path',
    help: 'pending, then validated (parks for admin review), then paid (network settlement only).',
    steps: [{ status: 'pending' }, { status: 'validated' }, { status: 'paid' }],
  },
  rejected: {
    label: 'Rejected',
    help: 'pending, then rejected by the network.',
    steps: [{ status: 'pending' }, { status: 'rejected' }],
  },
  reversal: {
    label: 'Reversal',
    help: 'pending, validated, then reversed after confirmation.',
    steps: [{ status: 'pending' }, { status: 'validated' }, { status: 'reversed' }],
  },
  duplicate: {
    label: 'Duplicate replays',
    help: 'identical updates sent twice; must stay one conversion and one cashback.',
    steps: [{ status: 'pending' }, { status: 'pending' }, { status: 'validated' }, { status: 'validated' }],
  },
  unattributable: {
    label: 'Unattributable',
    help: 'unknown sub_id: the conversion is kept for review, no cashback is created.',
    steps: [
      { status: 'pending', sub: 'unknown-subid-000' },
      { status: 'validated', sub: 'unknown-subid-000' },
    ],
  },
};

const DEFAULTS = { commission: 1200, saleAmount: 12000, currency: 'INR', campaignId: 'SIM-CAMPAIGN' };

/** A transaction id that is stable for a whole run, like the PowerShell script. */
export function newTransactionId(now = Date.now(), random = Math.random) {
  return 'SIM-' + now.toString(36).toUpperCase() + Math.floor(random() * 36 ** 4).toString(36).toUpperCase().padStart(4, '0');
}

/** The JSON body of one Transaction Update postback. */
export function buildPostback({ transactionId, subId, status, commission, saleAmount, currency, campaignId, now = new Date() }) {
  return {
    transaction_id: transactionId,
    campaign_id: campaignId ?? DEFAULTS.campaignId,
    sub_id: subId,
    status,
    sale_amount: saleAmount ?? DEFAULTS.saleAmount,
    commission: commission ?? DEFAULTS.commission,
    currency: currency ?? DEFAULTS.currency,
    transaction_date: new Date(now.getTime() - 2 * 3600 * 1000).toISOString(),
    updated_at: now.toISOString(),
  };
}

/** Checks user input; returns the cleaned values or throws a plain message. */
export function validateInput(input) {
  const subId = String(input.subId ?? '').trim();
  if (!subId) throw new InputError('Enter the subid of a tracked click.');
  if (subId.length > 200) throw new InputError('The subid is too long.');

  const transactionId = String(input.transactionId ?? '').trim() || newTransactionId();
  if (transactionId.length > 100) throw new InputError('The transaction id is too long.');

  const commission = toMoney(input.commission ?? DEFAULTS.commission, 'commission');
  const saleAmount = toMoney(input.saleAmount ?? DEFAULTS.saleAmount, 'sale amount');
  return { subId, transactionId, commission, saleAmount };
}

export class InputError extends Error {}

function toMoney(value, name) {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0 || n > 10_000_000) throw new InputError(`The ${name} must be a number from 0 to 10,000,000.`);
  return Math.round(n * 100) / 100;
}

/** The tracking reference (`subid`) in a merchant URL, or null. */
export function extractSubId(locationUrl) {
  try {
    const params = new URL(locationUrl).searchParams;
    const v = params.get('subid') ?? params.get('sub_id');
    return v && v.trim() ? v.trim() : null;
  } catch {
    return null;
  }
}

/** Checks the "create click" form; returns cleaned values or throws a plain message. */
export function validateClickInput(input) {
  const email = String(input.email ?? '').trim();
  const password = String(input.password ?? '');
  const storeId = String(input.storeId ?? '').trim();
  if (!email) throw new InputError('Enter the test user\'s email.');
  if (!password) throw new InputError('Enter the test user\'s password.');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(storeId)) throw new InputError('Choose a store.');
  return { email, password, storeId };
}

/** What the user's cashback should be, given the network share percent. */
export function expectedCashback(commission, sharePercent) {
  return Math.round(((commission * sharePercent) / 100) * 100) / 100;
}

/**
 * Decides whether the simulator may post to `target`. It only posts to the
 * local machine unless remote is explicitly allowed, so fake sales can never
 * reach a live server by accident.
 */
export function checkTarget(target, allowRemote = false) {
  let url;
  try {
    url = new URL(target);
  } catch {
    return { ok: false, local: false, reason: `"${target}" is not a valid address.` };
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return { ok: false, local: false, reason: 'The target must be http or https.' };
  const host = url.hostname.replace(/^\[|\]$/g, '');
  const local = host === 'localhost' || host === '127.0.0.1' || host === '::1' || host.endsWith('.localhost');
  if (!local && !allowRemote) {
    return { ok: false, local, reason: `${url.origin} is not a local address. Set SM_SIM_ALLOW_REMOTE=1 only if you really mean to send simulated sales there.` };
  }
  return { ok: true, local, origin: url.origin };
}
