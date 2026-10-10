#!/usr/bin/env node
// /api/admin/v1 money mutations — QA for WS7 admin-money (30d5d05) + decision 10
// STORED Idempotency-Key (289f8af). LAB backends only.
//
//   ORIGIN_BASE=http://localhost:4142 PSQL_DB=kyco_wapi_mobileqa \
//   [QA_MONEY_FIXTURES=tool/api-contract/.qa-money-fixtures.json] [PAYMENT_ID=… DAMAGE_CLAIM_ID=…] \
//   node tool/api-contract/admin-money.mjs
//
// Routes under test:
//   POST /api/admin/v1/payments/refunds   {paymentId, amountVnd, reason}
//   POST /api/admin/v1/insurance-fund     {amountVnd, reason, relatedBookingId?}
//   POST /api/admin/v1/insurance/claims   {damage_claim_id, insurer, coverage_type, claim_amount_vnd, ...}
//
// Fixtures: ids come from `npx tsx scripts/seed-qa-money-fixtures.ts` (4998929, run by
// rebuild-qa-db.sh, JSON in .qa-money-fixtures.json): payments.partial = momo paid 500,000
// on an unsettled booking with a prior succeeded 100,000 refund (remaining 400,000),
// damageClaims.approved = 2,000,000 approved, kyco_clearing 1,000,000, kyco_insurance 10M.
// No hand-written SQL fixtures. Env PAYMENT_ID / DAMAGE_CLAIM_ID still override.
// Run ≥5 min after any admin step-up (admin-transport) so "fresh-before=false".
// Every check snapshots row counts by SQL before/after (docker exec psql).
import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';

const ORIGIN = process.env.ORIGIN_BASE || 'http://localhost:4142';
if (/kyco\.vn/.test(ORIGIN)) { console.error('QA backends only'); process.exit(2); }
const PACE = Number(process.env.SMOKE_PACE_MS || 1200);
const PSQL_DB = process.env.PSQL_DB || 'kyco_wapi_mobileqa';
const FIX_PATH = process.env.QA_MONEY_FIXTURES || new URL('./.qa-money-fixtures.json', import.meta.url).pathname;
let FIX = null;
try { FIX = JSON.parse(fs.readFileSync(FIX_PATH, 'utf8')); } catch { /* env ids only */ }
if (FIX && FIX.db !== PSQL_DB) { console.error(`fixtures are for ${FIX.db}, PSQL_DB=${PSQL_DB}`); process.exit(2); }
const PAYMENT_ID = Number(process.env.PAYMENT_ID || FIX?.payments?.partial);
const DAMAGE_CLAIM_ID = Number(process.env.DAMAGE_CLAIM_ID || FIX?.damageClaims?.approved);
if (!PAYMENT_ID || !DAMAGE_CLAIM_ID) { console.error(`no fixture ids: run scripts/seed-qa-money-fixtures.ts (→ ${FIX_PATH}) or set PAYMENT_ID/DAMAGE_CLAIM_ID`); process.exit(2); }
const PAY_AMOUNT = Number(psql(`select amount_vnd::bigint from kycore.payments where id=${PAYMENT_ID}`));
const PAY_REMAINING = PAY_AMOUNT - Number(psql(`select coalesce(sum(amount_vnd),0)::bigint from kycore.refunds where payment_id=${PAYMENT_ID} and status in ('pending','succeeded')`));
console.log(`fixtures ${FIX ? FIX_PATH : '(env)'}: payment ${PAYMENT_ID} amount ${PAY_AMOUNT} remaining ${PAY_REMAINING}, damage claim ${DAMAGE_CLAIM_ID}`);
const ACC = {
  admin: [process.env.ADMIN_EMAIL || 'admin@qa.local', process.env.ADMIN_PASSWORD || 'Admin12345qa'],
  customer: ['demo@demo.local', 'demo12345'],
  tasker: ['tasker@qa.local', 'TaskerQa12345!'],
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const rec = (name, ok, detail = '') => {
  results.push({ name, ok, detail });
  const tag = ok === null ? 'SKIP' : ok ? 'PASS' : 'FAIL';
  console.log(`${tag}  ${name}  — ${detail}`);
};
const key = (p = 'qa') => `${p}-${randomUUID()}`;

async function req(method, path, { token, body, headers = {}, pace = true } = {}) {
  if (pace) await sleep(PACE);
  const h = { Accept: 'application/json', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  let b;
  if (body !== undefined) { h['Content-Type'] = 'application/json'; b = JSON.stringify(body); }
  const res = await fetch(ORIGIN + path, { method, headers: h, body: b, redirect: 'manual' });
  const text = await res.text();
  let json = null; try { json = JSON.parse(text); } catch { /* */ }
  return { status: res.status, json, text: text.slice(0, 300), replayed: res.headers.get('idempotent-replayed') };
}
const ev = (r) => `HTTP ${r.status} code=${r.json?.code ?? '-'} ${JSON.stringify(r.json?.fields ?? r.json?.data ?? r.json?.message ?? r.text).slice(0, 160)}`;

function psql(sql) {
  try {
    return execFileSync('docker', ['exec', 'appdroid-pg', 'psql', '-U', 'postgres', '-d', PSQL_DB, '-Atc', sql], { encoding: 'utf8' }).trim();
  } catch (e) { return `__ERR__ ${e.message.split('\n')[0]}`; }
}

async function bearer(role) {
  const [email, password] = ACC[role];
  const r = await req('POST', '/api/v1/auth/login', { body: { email, password } });
  return r.json?.data?.accessToken;
}

let ADMIN_ID = 0;
// Row counts per endpoint: [effect rows, ledger rows, audit rows, idem rows].
const SNAP = {
  refund: () => psql(`select
      (select count(*) from kycore.refunds where payment_id=${PAYMENT_ID}),
      (select count(*) from kycore.wallet_transactions where related_payment_id=${PAYMENT_ID}),
      (select count(*) from kycore.admin_audit where actor_user_id=${ADMIN_ID} and action='admin.refund.request'),
      (select count(*) from kycore.api_idempotency_keys where user_id=${ADMIN_ID} and scope='admin:payments.refunds')`),
  withdraw: () => psql(`select
      (select count(*) from kycore.insurance_fund_withdrawals),
      (select count(*) from kycore.wallet_transactions wt join kycore.wallets w on w.id=wt.wallet_id where w.owner_type='kyco_insurance'),
      (select count(*) from kycore.admin_audit where actor_user_id=${ADMIN_ID} and action='admin.insurance_fund.withdraw'),
      (select count(*) from kycore.api_idempotency_keys where user_id=${ADMIN_ID} and scope='admin:insurance-fund.withdraw')`),
  claim: () => psql(`select
      (select count(*) from kycore.insurance_claims),
      0,
      (select count(*) from kycore.admin_audit where actor_user_id=${ADMIN_ID} and action='admin.insurance.file'),
      (select count(*) from kycore.api_idempotency_keys where user_id=${ADMIN_ID} and scope='admin:insurance.claims.file')`),
};
const snap = (k) => SNAP[k]().split('|').map(Number);
const delta = (a, b) => b.map((v, i) => v - a[i]);
const dstr = (d) => `Δ[rows=${d[0]} ledger=${d[1]} audit=${d[2]} idem=${d[3]}]`;
const zero = (d) => d.every((x) => x === 0);

const ONLY = process.env.ONLY ? process.env.ONLY.split(',') : null;
const canon = (v) => JSON.stringify(v, (k, x) => (x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.keys(x).sort().map((q) => [q, x[q]])) : x));
const ENDPOINTS_ALL = [
  {
    id: 'refund',
    path: '/api/admin/v1/payments/refunds',
    valid: { paymentId: PAYMENT_ID, amountVnd: 50000, reason: 'QA admin-money refund' },
    diff: { paymentId: PAYMENT_ID, amountVnd: 60000, reason: 'QA admin-money refund' },
    ok: [200],
    bad: [
      ['amount 1.5', { amountVnd: 1.5 }], ['amount -1', { amountVnd: -1 }], ['amount 0', { amountVnd: 0 }],
      ['amount "abc"', { amountVnd: 'abc' }], ['amount numeric string "1000"', { amountVnd: '1000' }],
    ],
    // MQA-39 split (3e9d764): state-dependent limits are 409; the fixture has a prior 100,000 refund.
    conflict: [[`amount > remaining (${PAY_REMAINING + 1} with ${PAY_REMAINING} left on a ${PAY_AMOUNT} payment)`, { amountVnd: PAY_REMAINING + 1 }]],
    missingKeyBody: { paymentId: PAYMENT_ID, amountVnd: 10000, reason: 'QA admin-money missing key' },
  },
  {
    id: 'withdraw',
    path: '/api/admin/v1/insurance-fund',
    valid: { amountVnd: 1000000, reason: 'QA admin-money insurance withdraw' },
    diff: { amountVnd: 1200000, reason: 'QA admin-money insurance withdraw' },
    ok: [200],
    bad: [
      ['amount 1.5', { amountVnd: 1.5 }], ['amount -1', { amountVnd: -1 }], ['amount 0', { amountVnd: 0 }],
      ['amount "abc"', { amountVnd: 'abc' }], ['amount numeric string "1000"', { amountVnd: '1000' }],
      ['amount 5,000,001 > daily cap', { amountVnd: 5000001 }],
    ],
    // runs AFTER the 1,000,000 happy path: 1,000,000 + 4,500,000 > 5,000,000 VN-day cap
    after: [['amount 4,500,000 → cumulative today > 5,000,000 cap (MQA-39: 409)', { amountVnd: 4500000 }, 409]],
    missingKeyBody: { amountVnd: 100000, reason: 'QA admin-money missing key' },
  },
  {
    id: 'claim',
    path: '/api/admin/v1/insurance/claims',
    valid: { damage_claim_id: DAMAGE_CLAIM_ID, insurer: 'pti', coverage_type: 'property_damage', claim_amount_vnd: 2000000, notes: 'QA admin-money claim' },
    diff: { damage_claim_id: DAMAGE_CLAIM_ID, insurer: 'pti', coverage_type: 'property_damage', claim_amount_vnd: 1500000, notes: 'QA admin-money claim' },
    ok: [201],
    bad: [
      ['amount 1.5', { claim_amount_vnd: 1.5 }], ['amount -1', { claim_amount_vnd: -1 }], ['amount 0', { claim_amount_vnd: 0 }],
      ['amount "abc"', { claim_amount_vnd: 'abc' }], ['amount numeric string "1000"', { claim_amount_vnd: '1000' }],
      ['amount 100,000,001 > 100M bound', { claim_amount_vnd: 100000001 }],
    ],
    // MQA-40 (39cc604): Σ live claims ≤ the damage claim's approved amount (2,000,000 fixture) → 409.
    conflict: [['amount 3,000,000 > approved damage 2,000,000 (MQA-40)', { claim_amount_vnd: 3000000 }]],
    missingKeyBody: { damage_claim_id: DAMAGE_CLAIM_ID, insurer: 'pti', coverage_type: 'theft', claim_amount_vnd: 100000, notes: 'QA admin-money missing key' },
  },
];

const ENDPOINTS = ENDPOINTS_ALL.filter((E) => !ONLY || ONLY.includes(E.id));
async function stepUp(A) {
  const r = await req('POST', '/api/v1/auth/step-up', { token: A, body: { method: 'password', password: ACC.admin[1] } });
  rec('step-up POST /api/v1/auth/step-up {method:password}', r.status === 200, ev(r));
}

(async () => {
  const A = await bearer('admin'), C = await bearer('customer'), T = await bearer('tasker');
  rec('bearer logins (admin/customer/tasker)', !!(A && C && T), `admin=${!!A} customer=${!!C} tasker=${!!T}`);
  if (!A) process.exit(1);
  ADMIN_ID = Number(psql(`select id from kycore.users where email='${ACC.admin[0]}'`));
  const su = await req('GET', '/api/v1/auth/step-up', { token: A });
  const preFresh = su.json?.data?.fresh === true;
  console.log(`admin=${ACC.admin[0]} id=${ADMIN_ID} fresh-before=${preFresh}`);

  // ── 1. No fresh step-up → STEP_UP_REQUIRED, no change; customer/tasker → 403 ──
  for (const E of ENDPOINTS) {
    const s0 = snap(E.id);
    const r = await req('POST', E.path, { token: A, body: E.valid, headers: { 'Idempotency-Key': key() } });
    const d = delta(s0, snap(E.id));
    if (preFresh) rec(`${E.id}: no step-up → STEP_UP_REQUIRED`, null, 'admin already fresh');
    else rec(`${E.id}: no step-up → STEP_UP_REQUIRED, no change`, [401, 403].includes(r.status) && r.json?.code === 'STEP_UP_REQUIRED' && zero(d), `${ev(r)} ${dstr(d)}`);
    for (const [who, tok] of [['customer', C], ['tasker', T]]) {
      const s1 = snap(E.id);
      const r2 = await req('POST', E.path, { token: tok, body: E.valid, headers: { 'Idempotency-Key': key() } });
      const d2 = delta(s1, snap(E.id));
      rec(`${E.id}: ${who} Bearer → 403, no change`, r2.status === 403 && zero(d2), `${ev(r2)} ${dstr(d2)}`);
    }
  }

  for (const E of ENDPOINTS) {
    await stepUp(A);
    // ── validation: each refused with 422 and no effect / no audit ──
    for (const [label, patch] of E.bad) {
      const s = snap(E.id);
      const r = await req('POST', E.path, { token: A, body: { ...E.valid, ...patch }, headers: { 'Idempotency-Key': key() } });
      const d = delta(s, snap(E.id));
      rec(`${E.id}: ${label} → 422, no effect`, r.status === 422 && zero(d), `${ev(r)} ${dstr(d)}`);
    }
    for (const [label, patch] of E.conflict ?? []) {
      const s = snap(E.id);
      const r = await req('POST', E.path, { token: A, body: { ...E.valid, ...patch }, headers: { 'Idempotency-Key': key() } });
      const d = delta(s, snap(E.id));
      rec(`${E.id}: ${label} → 409, no effect`, r.status === 409 && zero(d), `${ev(r)} ${dstr(d)}`);
    }
    for (const [label, k] of [['malformed key "bad key!"', 'bad key!'], ['malformed key too short "abc"', 'abc'], ['malformed key 61 chars', 'x'.repeat(61)]]) {
      const s = snap(E.id);
      const r = await req('POST', E.path, { token: A, body: E.valid, headers: { 'Idempotency-Key': k } });
      const d = delta(s, snap(E.id));
      rec(`${E.id}: ${label} → 422, no effect`, r.status === 422 && zero(d), `${ev(r)} ${dstr(d)}`);
    }

    // ── happy path + replay ──
    const K = key('qa-ok');
    const s0 = snap(E.id);
    const r1 = await req('POST', E.path, { token: A, body: E.valid, headers: { 'Idempotency-Key': K } });
    const s1 = snap(E.id); const d1 = delta(s0, s1);
    const ledgerWant = E.id === 'claim' ? 0 : 1;
    rec(`${E.id}: step-up + key + valid body → ${E.ok[0]}, 1 row, ${ledgerWant} ledger, 1 audit, 1 idem`,
      E.ok.includes(r1.status) && d1[0] === 1 && d1[1] === ledgerWant && d1[2] === 1 && d1[3] === 1, `${ev(r1)} ${dstr(d1)}`);
    const r2 = await req('POST', E.path, { token: A, body: E.valid, headers: { 'Idempotency-Key': K } });
    const s2 = snap(E.id); const d2 = delta(s1, s2);
    const same = r2.status === r1.status && canon(r2.json) === canon(r1.json);
    const byteSame = r2.text === r1.text;
    rec(`${E.id}: SAME key + SAME body → identical replay (header idempotent-replayed)`, same && r2.replayed === 'true',
      `${ev(r2)} replayed=${r2.replayed} deep-equal=${same} byte-identical=${byteSame}${byteSame ? '' : ` first=${r1.text} replay=${r2.text}`}`);
    rec(`${E.id}: replay → no 2nd row / ledger`, d2[0] === 0 && d2[1] === 0 && d2[3] === 0, dstr(d2));
    rec(`${E.id}: replay → no 2nd admin_audit row`, d2[2] === 0, `${dstr(d2)} last audit: ${psql(`select id||' target='||coalesce(target_id,'NULL')||' after='||coalesce(after::text,'NULL') from kycore.admin_audit where actor_user_id=${ADMIN_ID} order by id desc limit 1`)}`);
    const r3 = await req('POST', E.path, { token: A, body: E.diff, headers: { 'Idempotency-Key': K } });
    const d3 = delta(s2, snap(E.id));
    rec(`${E.id}: SAME key + DIFFERENT body → 409/422, no effect`, [409, 422].includes(r3.status) && zero(d3), `${ev(r3)} ${dstr(d3)}`);

    for (const [label, patch, want = 422] of E.after ?? []) {
      const s = snap(E.id);
      const r = await req('POST', E.path, { token: A, body: { ...E.valid, ...patch }, headers: { 'Idempotency-Key': key() } });
      const d = delta(s, snap(E.id));
      rec(`${E.id}: ${label} → ${want}, no effect`, r.status === want && zero(d), `${ev(r)} ${dstr(d)}`);
    }

    // ── missing key (spec: 422; decision 10: optional on Bearer) ──
    const s4 = snap(E.id);
    const r4 = await req('POST', E.path, { token: A, body: E.missingKeyBody });
    const d4 = delta(s4, snap(E.id));
    rec(`${E.id}: missing Idempotency-Key (Bearer) → 422, no effect`, r4.status === 422 && zero(d4), `${ev(r4)} ${dstr(d4)}`);
  }

  if (ONLY && !ONLY.includes('refund')) { summary(); return; }
  // ── 2. Concurrency: same refund, same key, fired in parallel ──
  await stepUp(A);
  const KC = key('qa-conc');
  const body = { paymentId: PAYMENT_ID, amountVnd: 20000, reason: 'QA admin-money concurrency' };
  const sc = snap('refund');
  const rs = await Promise.all([0, 1].map(() => req('POST', '/api/admin/v1/payments/refunds', { token: A, body, headers: { 'Idempotency-Key': KC }, pace: false })));
  await sleep(1500);
  const dc = delta(sc, snap('refund'));
  rec('refund: 2 parallel same key → exactly one effect', dc[0] === 1 && dc[1] === 1 && rs.filter((r) => r.status === 200).length >= 1,
    `${rs.map(ev).join(' | ')} ${dstr(dc)}`);
  // and with a fresh key per call (the payment lock alone):
  const sc2 = snap('refund');
  const rs2 = await Promise.all([0, 1].map(() => req('POST', '/api/admin/v1/payments/refunds', { token: A, body: { ...body, amountVnd: 1000 }, headers: { 'Idempotency-Key': key('qa-conc2') }, pace: false })));
  await sleep(1500);
  const dc2 = delta(sc2, snap('refund'));
  rec('refund: 2 parallel DIFFERENT keys (info: lock → one 409)', null, `${rs2.map(ev).join(' | ')} ${dstr(dc2)}`);

  summary();
})();

function summary() {
  console.log(`\nrefund Σ for payment ${PAYMENT_ID}: ${psql(`select coalesce(sum(amount_vnd),0)||' / '||(select amount_vnd from kycore.payments where id=${PAYMENT_ID}) from kycore.refunds where payment_id=${PAYMENT_ID} and status in ('pending','succeeded')`)}`);
  const fail = results.filter((r) => r.ok === false).length;
  console.log(`\n${results.filter((r) => r.ok).length} pass, ${fail} fail, ${results.filter((r) => r.ok === null).length} skip`);
  process.exit(fail ? 1 : 0);
}
