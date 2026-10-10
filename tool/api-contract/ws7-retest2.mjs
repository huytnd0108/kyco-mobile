// Mobile-QA RE-TEST round 2 (feat/web-api-only ≥ 1b2e0dc) — LAB ONLY (kyco_wapi_mobileqa).
//   API_ORIGIN=http://127.0.0.1:4142 node tool/api-contract/ws7-retest2.mjs [--only=role,sos,disputes,subs,tz,checkin,fund,booktz,vrf5]
// + MQA-51 trace header (--only=trace), MQA-52 error log by severity (errlog; needs SERVER_LOG=<next start log>),
//   MQA-53 seed guard / dispute reopen / cancellable pair (seed).
// Covers: MQA-46/VRF-4 role gate (photos/face-verify), MQA-44 SOS contract, disputes respond/resolve
// (bcfb263/12ea497), subscriptions durationHours (6cb73a9), MQA-45 weekly-availability conflict (1e37fc4),
// MQA-24/41 unverified check-in + events.user_id (478e453), MQA-40 fund floor (39cc604),
// booking scheduledAt with an hour-only offset, VRF-5 anonymous public-page burst (d8a9eff).
// fe-audit sync (≥ ac0d5e5): --only=kyc (MQA-58 every KYC door + read headers), pool (Z2 privacy, distanceKm,
//   taskerNetVnd 8edc05d), window (FE-06 check-in/out window + admin override), export (ae0cc41), mqa56 (MQA-56/57).
//   needs RT2_FIXTURES dir with real.jpg/png/webp (≥10 KB) and the lab fake GCS (GCS_API_ENDPOINT/GCS_BUCKET).
// Fixtures are created by SQL (docker exec appdroid-pg psql) and refuse any other DB.
import { execFileSync, spawn } from 'node:child_process';
import net from 'node:net';
import os from 'node:os';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import { createRequire } from 'node:module';

const ORIGIN = process.env.API_ORIGIN || 'http://127.0.0.1:4142';
if (/kyco\.vn/.test(ORIGIN)) { console.error('lab only'); process.exit(2); }
const DB = 'kyco_wapi_mobileqa';
const PACE = Number(process.env.PACE_MS ?? 400);
const LOGIN_GAP = Number(process.env.LOGIN_GAP_MS ?? 12500);
const TOKCACHE = process.env.RT2_TOKEN_CACHE || '/tmp/claude-1000/-home-bi-w-AppDroid1-ori/e83cad69-666e-4383-b5b7-0d5045b1a7d0/scratchpad/rt2-tokens.json';
const ONLY = (process.argv.find((a) => a.startsWith('--only=')) || '').slice(7).split(',').filter(Boolean);
const on = (k) => ONLY.length === 0 || ONLY.includes(k);
const ACC = {
  customer: ['demo@demo.local', 'demo12345'],
  tasker: ['tasker@qa.local', 'TaskerQa12345!'],
  tasker2: ['tasker2@qa.local', 'TaskerQa12345!'],
  admin: ['admin@qa.local', 'Admin12345qa'],
  staff: ['staff-disputes@qa.local', 'StaffQa12345!'],
  qamoney: ['qa-money-customer@qa.local', 'Qa12345money'],   // seed-qa-money-fixtures customer (MQA-53 cancel)
};
const WT = process.env.KYCO_WT || '/home/bi/w/AppDroid1-ori/kyco-wt/mobile-qa';
// ids printed by scripts/seed-qa-money-fixtures.ts (rebuild-qa-db.sh saves them here)
let FIX = null;
try { FIX = JSON.parse(fs.readFileSync(process.env.QA_MONEY_FIXTURES || new URL('./.qa-money-fixtures.json', import.meta.url).pathname, 'utf8')); } catch { /* SQL fallback */ }
if (FIX && FIX.db !== DB) { console.error(`fixtures are for ${FIX.db}, not ${DB}`); process.exit(2); }
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
function rec(g, name, ok, detail = '') {
  results.push({ g, name, ok, detail });
  console.log(`${ok === null ? 'INFO' : ok ? 'PASS' : 'FAIL'}  [${g}] ${name}  — ${detail}`);
}
function sql(q) {
  return execFileSync('docker', ['exec', 'appdroid-pg', 'psql', '-U', 'postgres', '-d', DB, '-qAtc', `set search_path=kycore,public; ${q}`], { encoding: 'utf8' }).trim();
}
let lastLogin = 0;
async function req(method, path, { token, body, headers = {}, raw } = {}) {
  await sleep(PACE);
  if (path === '/api/v1/auth/login') { const w = lastLogin + LOGIN_GAP - Date.now(); if (w > 0) await sleep(w); lastLogin = Date.now(); }
  const h = { Accept: 'application/json', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  let b = raw;
  if (body !== undefined) { h['Content-Type'] = 'application/json'; b = JSON.stringify(body); }
  const res = await fetch(ORIGIN + path, { method, headers: h, body: b, redirect: 'manual' });
  const text = await res.text();
  let json = null; try { json = JSON.parse(text); } catch { /* html */ }
  return { status: res.status, json, text, data: json?.data ?? json, replayed: res.headers.get('idempotent-replayed'), trace: res.headers.get('x-trace-id') };
}
const ev = (r) => `HTTP ${r.status} ${r.json ? JSON.stringify({ code: r.json.code, fields: r.json.fields, data: r.json.data, traceId: r.json.traceId }).slice(0, 260) : r.text.slice(0, 120)}`;
const key = (p = 'rt2') => `${p}-${randomUUID()}`;

// rebuild-qa-db.sh only creates demo/admin/tasker: (re)create tasker2 (its own taskers row, so
// taskers.id ≠ users.id for MQA-41) and a staff user holding only admin:disputes:read. Idempotent.
const lit = (v) => `'${String(v).replace(/'/g, "''")}'`;
function ensureLabAccounts() {
  const bcrypt = createRequire(`${WT}/package.json`)('bcryptjs');
  const ensure = (email, pw, role, name) => {
    const h = bcrypt.hashSync(pw, 10);
    sql(`insert into users (email,password_hash,name,role,is_active,token_version) select ${lit(email)},${lit(h)},${lit(name)},${lit(role)},true,0 where not exists (select 1 from users where email=${lit(email)})`);
    sql(`update users set password_hash=${lit(h)}, role=${lit(role)}, is_active=true where email=${lit(email)}`);
    return Number(sql(`select id from users where email=${lit(email)}`));
  };
  const u2 = ensure(ACC.tasker2[0], ACC.tasker2[1], 'tasker', 'RT2 Tasker2');
  let t2 = Number(sql(`select id from taskers where user_account_id=${u2}`));
  if (!t2) t2 = Number(sql(`update taskers set user_account_id=${u2}, is_verified=true, is_banned=false, suspended_until=null where id=(select min(id) from taskers where user_account_id is null and id>1) returning id`).split('\n')[0]);
  const us = ensure(ACC.staff[0], ACC.staff[1], 'staff', 'RT2 Staff disputes');
  sql(`insert into user_scopes (user_id,scope,granted_at,reason) select ${us},'admin:disputes:read',now(),'rt2 lab' where not exists (select 1 from user_scopes where user_id=${us} and scope='admin:disputes:read' and revoked_at is null)`);
  return { T2U: u2, T2T: t2 };
}

async function tokens() {
  let cache = {};
  try { cache = JSON.parse(fs.readFileSync(TOKCACHE, 'utf8')); } catch { /* none */ }
  const out = {};
  for (const [role, [email, password]] of Object.entries(ACC)) {
    const c = cache[role];
    if (c && c.exp > Date.now() + 120_000) {
      const me = await req('GET', '/api/v1/me', { token: c.token });
      if (me.status === 200) { out[role] = c.token; continue; }
    }
    const r = await req('POST', '/api/v1/auth/login', { body: { email, password } });
    out[role] = r.data?.accessToken;
    rec('setup', `login ${role}`, !!out[role], r.status === 200 ? 'ok' : ev(r));
    if (out[role]) cache[role] = { token: out[role], exp: Date.now() + 10 * 60_000 };
  }
  fs.writeFileSync(TOKCACHE, JSON.stringify(cache));
  return out;
}
async function stepUp(tok, password) {
  const r = await req('POST', '/api/v1/auth/step-up', { token: tok, body: { method: 'password', password } });
  return r.status;
}

async function main() {
  console.log(`ws7-retest2 against ${ORIGIN}`);
  const { T2U, T2T } = ensureLabAccounts();
  rec('setup', 'lab accounts', null, `tasker2 users.id=${T2U} taskers.id=${T2T}`);
  const T = await tokens();
  const C = T.customer, P = T.tasker, P2 = T.tasker2, A = T.admin, S = T.staff;
  const sl = await req('GET', '/api/v1/services?page=1&limit=10', { token: C });
  const svc = Number((sl.data?.items ?? sl.data ?? [])[0]?.id) || Number(sql(`select min(id) from services where is_active`));
  rec('setup', 'bookable service', null, `serviceId=${svc}`);
  const anyJob = Number(sql(`select min(id) from jobs`));

  // ── MQA-46 / VRF-4: role gate before ownership on photos + face-verify ──
  if (on('role')) {
    for (const [who, tok] of [['customer', C], ['admin', A]]) {
      for (const door of ['photos', 'face-verify']) {
        for (const id of [anyJob, 99999999]) {
          const body = door === 'photos' ? { slot: 'before', mediaIds: [1] } : { selfieMediaId: 1 };
          const r = await req('POST', `/api/v1/tasker/jobs/${id}/${door}`, { token: tok, body });
          rec('role', `${who} POST /tasker/jobs/${id}/${door} → 403`, r.status === 403, ev(r));
        }
      }
    }
  }

  // ── MQA-44: SOS contract ──
  if (on('sos')) {
    const custBooking = Number(sql(`select min(id) from bookings where user_id=1`));
    const before = Number(sql(`select count(*) from sos_events`));
    const a = await req('POST', '/api/v1/sos', { token: P2, body: { bookingId: custBooking, note: 'rt2 foreign booking' } });
    rec('sos', '(a) tasker2 foreign bookingId → 201, bookingAttached:false', a.status === 201 && a.data?.bookingAttached === false && a.data?.jobAttached === false, ev(a));
    const row = a.data?.id ? sql(`select coalesce(booking_id::text,'NULL')||'|'||triggered_by_user_id from sos_events where id=${Number(a.data.id)}`) : '-';
    rec('sos', '(a) stored row booking_id NULL', row.startsWith('NULL|'), row);
    const b = await req('POST', '/api/v1/sos', { token: P2, body: { foo: 1, bar: 'x' } });
    rec('sos', '(b) unknown keys → 2xx + ignoredFields [foo,bar] (deduped within 90 s ok)', [200, 201].includes(b.status) && JSON.stringify(b.data?.ignoredFields?.slice().sort()) === '["bar","foo"]', ev(b));
    const c = await req('POST', '/api/v1/sos', { token: P2, body: { bookingId: custBooking, jobId: 99999999 } });
    rec('sos', '(c) open SOS <90 s + foreign refs → deduped, attached flags false', c.status === 200 && c.data?.deduped === true && c.data?.bookingAttached === false && c.data?.jobAttached === false, ev(c));
    const own = await req('POST', '/api/v1/sos', { token: C, body: { bookingId: custBooking, note: 'rt2 own booking' } });
    rec('sos', 'customer own booking → 201 bookingAttached:true', [200, 201].includes(own.status) && own.data?.bookingAttached === true, ev(own));
    const bad = await req('POST', '/api/v1/sos', { token: C, body: { category: 'not-a-category' } });
    rec('sos', 'bad known field (category) → 422', bad.status === 422, ev(bad));
    rec('sos', 'rows created', null, `${before} → ${sql('select count(*) from sos_events')}`);
    sql(`update sos_events set status='resolved', resolved_at=now() where status <> 'resolved' and notes like 'rt2%' or (status <> 'resolved' and triggered_by_user_id in (1,${T2U}))`);
  }

  // ── Disputes (bcfb263 respond, 12ea497 resolve) ──
  if (on('disputes')) {
    const bk = Number(sql(`select min(id) from bookings where user_id=1`));
    const ins = (cat) => Number(sql(`insert into disputes(booking_id,customer_user_id,tasker_id,category,description,status,opened_at) values (${bk},1,1,'${cat}','rt2 QA dispute','open',now()) returning id`).split('\n')[0]);
    // A/B need tasker #1 as the assigned tasker (respond flow) → own SQL rows. C/D (admin resolve only)
    // come from seed-qa-money-fixtures.ts (disputes.a/b) when still open; E/F (b531a81 positive-amount
    // outcomes) need two more open disputes than the seed provides → SQL.
    const fxOpen = (id) => (id && sql(`select status from disputes where id=${Number(id)}`) === 'open' ? Number(id) : 0);
    const dA = ins('other'), dB = ins('other');
    const dC = fxOpen(FIX?.disputes?.a) || ins('other'), dD = fxOpen(FIX?.disputes?.b) || ins('other');
    const dE = ins('other'), dF = ins('other');
    rec('disputes', 'fixtures', null, `A=${dA} B=${dB} (booking ${bk}, tasker#1) C=${dC} D=${dD} (seed ${FIX?.disputes?.a}/${FIX?.disputes?.b}${dC === Number(FIX?.disputes?.a) ? '' : ' — seed dispute not open, SQL fallback'}) E=${dE} F=${dF}`);
    const strict = !!process.env.DISPUTE_AMOUNT_FIX;
    const stmt = { statement: 'QA statement from the assigned tasker.' };
    let r = await req('POST', `/api/v1/disputes/${dA}/response`, { token: P2, body: stmt });
    rec('disputes', 'other tasker responds → 404', r.status === 404, ev(r));
    r = await req('POST', `/api/v1/disputes/999999/response`, { token: P, body: stmt });
    rec('disputes', 'unknown dispute → 404', r.status === 404, ev(r));
    r = await req('POST', `/api/v1/disputes/${dA}/response`, { token: P, body: { statement: 'short' } });
    rec('disputes', 'statement < 10 chars → 422', r.status === 422, ev(r));
    r = await req('POST', `/api/v1/disputes/${dA}/response`, { token: P, body: { ...stmt, extra: 1 } });
    rec('disputes', 'unknown key → 422', r.status === 422, ev(r));
    r = await req('POST', `/api/v1/disputes/${dA}/response`, { token: C, body: stmt });
    rec('disputes', 'customer → 403/404', [403, 404].includes(r.status), ev(r));
    r = await req('POST', `/api/v1/disputes/${dA}/response`, { token: P, body: stmt });
    rec('disputes', 'own tasker responds → 2xx, statement stored', r.status === 200 && sql(`select cleaner_statement is not null from disputes where id=${dA}`) === 't', ev(r));

    const audits = (id) => Number(sql(`select count(*) from admin_audit where action='admin.dispute.resolve' and target_id='${id}'`));
    const auditsAll = () => Number(sql(`select count(*) from admin_audit where action='admin.dispute.resolve'`));
    // 2fc35bf: dismissed is server-derived → amountVnd must be ABSENT (even 0 → 422).
    const resolveBody = { resolutionType: 'dismissed', notes: 'rt2 QA resolve' };
    r = await req('POST', `/api/admin/v1/disputes/${dB}`, { token: S, body: resolveBody, headers: { 'Idempotency-Key': key() } });
    rec('disputes', 'staff with only admin:disputes:read → 403', r.status === 403 && sql(`select status from disputes where id=${dB}`) === 'open', ev(r));
    rec('disputes', 'admin step-up', null, `HTTP ${await stepUp(A, ACC.admin[1])}`);
    r = await req('POST', `/api/admin/v1/disputes/${dB}`, { token: A, body: resolveBody });
    rec('disputes', 'missing Idempotency-Key (Bearer) → 422, unchanged', r.status === 422 && sql(`select status from disputes where id=${dB}`) === 'open', ev(r));
    for (const [label, amt] of [['"1000"', '1000'], ['1.5', 1.5], ['-1', -1]]) {
      r = await req('POST', `/api/admin/v1/disputes/${dB}`, { token: A, body: { ...resolveBody, resolutionType: 'goodwill', amountVnd: amt }, headers: { 'Idempotency-Key': key() } });
      rec('disputes', `amountVnd ${label} → 422`, r.status === 422, ev(r));
    }
    r = await req('POST', `/api/admin/v1/disputes/${dB}`, { token: A, body: { notes: 'x' }, headers: { 'Idempotency-Key': key() } });
    rec('disputes', 'missing resolutionType → 422', r.status === 422, ev(r));
    r = await req('POST', `/api/admin/v1/disputes/999999`, { token: A, body: resolveBody, headers: { 'Idempotency-Key': key() } });
    rec('disputes', 'unknown dispute → 404', r.status === 404, ev(r));
    const K = key('rt2-res');
    const a0 = auditsAll();
    const r1 = await req('POST', `/api/admin/v1/disputes/${dB}`, { token: A, body: resolveBody, headers: { 'Idempotency-Key': K } });
    const a1 = auditsAll();
    rec('disputes', 'admin resolve (scope + step-up + key) → 200, exactly 1 audit row', r1.status === 200 && a1 - a0 === 1 && audits(dB) === 1, `${ev(r1)} audit Δ=${a1 - a0} status=${sql(`select status from disputes where id=${dB}`)}`);
    const r2 = await req('POST', `/api/admin/v1/disputes/${dB}`, { token: A, body: resolveBody, headers: { 'Idempotency-Key': K } });
    rec('disputes', 'replay same key → identical, replayed header, no 2nd audit', r2.status === r1.status && JSON.stringify(Object.entries(r2.data ?? {}).sort()) === JSON.stringify(Object.entries(r1.data ?? {}).sort()) && r2.replayed === 'true' && auditsAll() === a1, `${ev(r2)} replayed=${r2.replayed} byte-identical=${r2.text === r1.text} audit Δ=${auditsAll() - a1}`);
    const r3 = await req('POST', `/api/admin/v1/disputes/${dB}`, { token: A, body: { ...resolveBody, notes: 'different' }, headers: { 'Idempotency-Key': K } });
    rec('disputes', 'same key + different body → 409/422', [409, 422].includes(r3.status), ev(r3));
    const r4 = await req('POST', `/api/admin/v1/disputes/${dB}`, { token: A, body: resolveBody, headers: { 'Idempotency-Key': key() } });
    rec('disputes', 're-resolve (new key) → 409', r4.status === 409 && auditsAll() === a1, ev(r4));
    // Decision (orchestrator): amountVnd REQUIRED for client-amount outcomes (partial_refund, goodwill) and
    // FORBIDDEN for server-derived ones (refund, dismissed, …); never defaulted. Asserted when the fix lands
    // (DISPUTE_AMOUNT_FIX=1); until then the observed behaviour is recorded as INFO.
    const r5 = await req('POST', `/api/admin/v1/disputes/${dC}`, { token: A, body: { resolutionType: 'partial_refund', notes: 'rt2 partial no amount' }, headers: { 'Idempotency-Key': key() } });
    const st5 = sql(`select status||' amount='||coalesce(resolution_amount_vnd::text,'NULL') from disputes where id=${dC}`);
    rec('disputes', 'partial_refund WITHOUT amountVnd → 422 fields.amountVnd, unchanged', strict ? (r5.status === 422 && 'amountVnd' in (r5.json?.fields ?? {}) && st5.startsWith('open')) : null, `${ev(r5)} row=${st5}${strict ? '' : (r5.status === 200 ? ' — STILL DEFAULTS TO 0 (fix not merged)' : '')}`);
    const r6 = await req('POST', `/api/admin/v1/disputes/${dD}`, { token: A, body: { resolutionType: 'dismissed', amountVnd: 50000, notes: 'rt2 dismissed with amount' }, headers: { 'Idempotency-Key': key() } });
    const st6 = sql(`select status||' amount='||coalesce(resolution_amount_vnd::text,'NULL') from disputes where id=${dD}`);
    rec('disputes', 'dismissed WITH amountVnd 50000 (server-derived outcome) → 422, unchanged', strict ? (r6.status === 422 && st6.startsWith('open')) : null, `${ev(r6)} row=${st6}${strict ? '' : (r6.status === 200 ? ' — amount accepted on a server-derived outcome (fix not merged)' : '')}`);
    if (strict) {
      for (const [rt, body, want] of [
        ['goodwill', { resolutionType: 'goodwill', notes: 'rt2 goodwill no amount' }, 'required'],
        ['insurance_claim', { resolutionType: 'insurance_claim', notes: 'rt2 claim no amount' }, 'required'],
        ['dismissed amountVnd 0', { resolutionType: 'dismissed', amountVnd: 0, notes: 'rt2 dismissed zero' }, 'forbidden'],
        ['refund amountVnd 10000', { resolutionType: 'refund', amountVnd: 10000, notes: 'rt2 refund with amount' }, 'forbidden'],
      ]) {
        const r = await req('POST', `/api/admin/v1/disputes/${dC}`, { token: A, body, headers: { 'Idempotency-Key': key() } });
        rec('disputes', `${rt} (${want}) → 422 fields.amountVnd, unchanged`, r.status === 422 && 'amountVnd' in (r.json?.fields ?? {}) && sql(`select status from disputes where id=${dC}`) === 'open', ev(r));
      }
      // b531a81: amount-carrying outcomes need amountVnd > 0 ("must be > 0 for this resolution").
      for (const rt of ['partial_refund', 'goodwill', 'insurance_claim']) {
        const a0 = auditsAll();
        const z = await req('POST', `/api/admin/v1/disputes/${dC}`, { token: A, body: { resolutionType: rt, amountVnd: 0, notes: `rt2 ${rt} zero` }, headers: { 'Idempotency-Key': key() } });
        const row = sql(`select status||' amount='||coalesce(resolution_amount_vnd::text,'NULL') from disputes where id=${dC}`);
        rec('disputes', `b531a81 ${rt} amountVnd 0 → 422 "must be > 0 for this resolution", unchanged, no audit`,
          z.status === 422 && /must be > 0 for this resolution/.test(String(z.json?.fields?.amountVnd ?? '')) && row.startsWith('open') && auditsAll() === a0, `${ev(z)} row=${row}`);
      }
      for (const [rt, id, amt] of [['partial_refund', dC, 10000], ['goodwill', dE, 15000], ['insurance_claim', dF, 20000]]) {
        const a0 = auditsAll(), ic0 = Number(sql('select count(*) from insurance_claims'));
        const ok = await req('POST', `/api/admin/v1/disputes/${id}`, { token: A, body: { resolutionType: rt, amountVnd: amt, notes: `rt2 ${rt} ${amt}` }, headers: { 'Idempotency-Key': key() } });
        const row = sql(`select status||' type='||coalesce(resolution_type,'-')||' amount='||coalesce(resolution_amount_vnd::int::text,'NULL') from disputes where id=${id}`);
        rec('disputes', `b531a81 ${rt} amountVnd ${amt} → 200, stored, exactly 1 audit row`,
          ok.status === 200 && row.startsWith('resolved') && row.endsWith(`amount=${amt}`) && auditsAll() - a0 === 1 && audits(id) === 1,
          `${ev(ok)} row=${row} audit Δ=${auditsAll() - a0}${rt === 'insurance_claim' ? ` insurance_claims Δ=${Number(sql('select count(*) from insurance_claims')) - ic0}` : ''}`);
      }
      const d2 = await req('POST', `/api/admin/v1/disputes/${dD}`, { token: A, body: { resolutionType: 'dismissed', notes: 'rt2 dismissed no amount' }, headers: { 'Idempotency-Key': key() } });
      rec('disputes', 'dismissed WITHOUT amountVnd → 200', d2.status === 200 && sql(`select status from disputes where id=${dD}`) === 'resolved', ev(d2));
    }
    r = await req('POST', `/api/v1/disputes/${dB}/response`, { token: P, body: stmt });
    rec('disputes', 'own tasker responds on a RESOLVED dispute → 409', r.status === 409, ev(r));
  }

  // ── Subscriptions durationHours (6cb73a9) ──
  if (on('subs')) {
    const base = Number(sql(`select base_price_vnd from services where id=${svc}`));
    const body = (h) => ({ frequency: 'weekly', packageMonths: 1, serviceId: svc, slotDayOfWeek: 2, slotTimeMinutes: 540, addressLine: '12 Lê Lợi', district: 'Quận 1', ward: 'Bến Nghé', ...(h === undefined ? {} : { durationHours: h }) });
    for (const h of [1.5, '4', 0, -1, 5]) {
      const n0 = sql('select count(*) from subscriptions');
      const r = await req('POST', '/api/v1/subscriptions', { token: C, body: body(h), headers: { 'Idempotency-Key': key() } });
      const keys = Object.keys(r.json?.fields ?? {});
      rec('subs', `durationHours ${JSON.stringify(h)} → 422 fields.durationHours, no row`, r.status === 422 && keys.includes('durationHours') && sql('select count(*) from subscriptions') === n0, `${ev(r)} fieldKeys=${keys.join(',')}`);
    }
    const totals = {};
    for (const h of [2, 3, 4, undefined]) {
      const r = await req('POST', '/api/v1/subscriptions', { token: C, body: body(h), headers: { 'Idempotency-Key': key() } });
      const id = r.data?.id;
      const row = id ? sql(`select duration_hours||'|'||total_amount_vnd||'|'||sessions_total||'|'||discount_pct from subscriptions where id=${id}`) : '-';
      totals[h ?? 'omitted'] = row;
      const [dh] = row.split('|').map(Number);
      rec('subs', `durationHours ${h ?? 'omitted'} → 201, stored ${h ?? 3}h`, r.status === 201 && dh === (h ?? 3), `${ev(r)} row=${row}`);
    }
    const t = (k) => Number(String(totals[k]).split('|')[1]);
    const ok = t(2) > 0 && t(3) * 2 === t(2) * 3 && t(4) * 2 === t(2) * 4 && t('omitted') === t(3);
    rec('subs', `server price = base(${base}) × hours (total ∝ hours; omitted = 3h)`, ok, JSON.stringify(totals));
    sql(`update subscriptions set status='cancelled', ended_at=now() where user_id=1 and address_line='12 Lê Lợi' and status<>'cancelled'`);
  }

  // ── MQA-45: weekly availability conflict on a stored timestamptz ──
  if (on('tz')) {
    // Fixture: booking scheduled 2026-12-06 02:00 UTC = Sun 09:00 VN, job pending for tasker #1.
    const bk = Number(sql(`select max(id) from bookings where user_id=1 and status not in ('CANCELLED','COMPLETED')`));
    const prevSvc = sql(`select service_id from bookings where id=${bk}`);
    const shortSvc = Number(sql(`select id from services where duration_minutes between 15 and 60 order by id limit 1`));
    sql(`update bookings set scheduled_at='2026-12-06 02:00:00+00', status='CONFIRMED', service_id=${shortSvc} where id=${bk}`);
    rec('tz', 'fixture service duration', null, `service ${shortSvc} = ${sql(`select duration_minutes from services where id=${shortSvc}`)} min`);
    const job = Number(sql(`select id from jobs where booking_id=${bk} limit 1`)) || Number(sql(`insert into jobs(booking_id,status) values (${bk},'pending') returning id`).split('\n')[0]);
    const prev = sql(`select tasker_id||'|'||status from jobs where id=${job}`);
    sql(`update jobs set tasker_id=1, status='pending' where id=${job}`);
    const raw = await req('GET', `/api/v1/tasker/jobs/${job}`, { token: P });
    rec('tz', 'fixture job scheduled_at as served', null, `job ${job} booking ${bk}: ${JSON.stringify(raw.data?.scheduledAt ?? raw.data?.booking?.scheduledAt ?? raw.status)}`);
    // Other days fully open + assert on THIS job only: tasker #1 may hold other committed jobs (flows/retest).
    const full = [{ start: 0, end: 1440 }];
    const grid = (sun) => ({ 0: sun, 1: full, 2: full, 3: full, 4: full, 5: full, 6: full });
    const hasJob = (r) => (r.data?.conflicts ?? []).map(String).includes(String(job));
    const w1 = await req('PUT', '/api/v1/tasker/availability/weekly', { token: P, body: { force: false, days: grid([{ start: 480, end: 1080 }]) } });
    rec('tz', 'grid Sun 08:00–18:00 covers Sun 09:00 VN job → job not a conflict', w1.status === 200 && !hasJob(w1), ev(w1));
    const w2 = await req('PUT', '/api/v1/tasker/availability/weekly', { token: P, body: { force: false, days: grid([{ start: 120, end: 150 }]) } });
    rec('tz', 'grid Sun 02:00–02:30 only → saved:false, conflicts include job', w2.status === 200 && w2.data?.saved === false && hasJob(w2), ev(w2));
    const w3 = await req('PUT', '/api/v1/tasker/availability/weekly', { token: P, body: { force: true, days: {} } });
    rec('tz', 'restore (force:true, empty)', null, ev(w3));
    sql(`delete from tasker_availability where tasker_id=1 and specific_date is null`);
    sql(`update bookings set service_id=${prevSvc} where id=${bk}`);
    sql(`update jobs set tasker_id=${prev.split('|')[0] || 'NULL'}, status='${prev.split('|')[1] || 'pending'}' where id=${job}`);
  }

  // ── MQA-24 / MQA-41: check-in on a booking WITHOUT coords, tasker2 (taskers.id ≠ users.id) ──
  if (on('checkin')) {
    const bk = Number(sql(`select min(id) from bookings where user_id=1 and id not in (select booking_id from jobs where booking_id is not null and tasker_id is not null) and status not in ('CANCELLED','COMPLETED')`));
    sql(`update bookings set address_lat=null, address_lng=null, scheduled_at=now()+interval '10 minutes', status='CONFIRMED' where id=${bk}`);
    let job = Number(sql(`select id from jobs where booking_id=${bk} limit 1`));
    if (!job) job = Number(sql(`insert into jobs(booking_id,status,tasker_id) values (${bk},'pending',${T2T}) returning id`).split('\n')[0]);
    sql(`update jobs set tasker_id=${T2T}, status='pending' where id=${job}`);
    sql(`delete from tasker_check_ins where job_id=${job}`);
    const e0 = Number(sql(`select coalesce(max(id),0) from events`));
    const r = await req('POST', `/api/v1/tasker/jobs/${job}/check-in`, { token: P2, body: { lat: 10.7769, lon: 106.7009, accuracyM: 12 } });
    rec('checkin', 'unverified check-in → 201, geofenceWithin null, geofenceStatus unverified', r.status === 201 && r.data?.geofenceWithin === null && r.data?.geofenceStatus === 'unverified', ev(r));
    await sleep(1500);
    const evs = sql(`select kind||':'||coalesce(user_id::text,'NULL') from events where id>${e0} order by id`);
    rec('checkin', `MQA-41: events.user_id = tasker2 users.id ${T2U} (not taskers.id ${T2T})`, evs.includes(`checkin_geofence_unverified:${T2U}`) && !evs.split('\n').some((l) => l.endsWith(`:${T2T}`)), evs.replace(/\n/g, ' ') || '(no events)');
    const ci = sql(`select coalesce(within_geofence::text,'NULL') from tasker_check_ins where job_id=${job} and event_kind='arrival'`);
    rec('checkin', 'arrival row within_geofence NULL', ci === 'NULL', ci);
    // MQA-24 create path: mobile booking body → are coords resolved?
    const b = await req('POST', '/api/v1/bookings', { token: C, body: { serviceId: svc, scheduledAt: '2026-12-20T09:00:00', district: 'Quận 1', ward: 'Bến Nghé', addressLine: '12 Lê Lợi', notes: 'rt2', paymentMethod: 'cash', idempotencyKey: randomUUID() } });
    const id = b.data?.bookingId;
    await sleep(2000);
    rec('checkin', 'MQA-24 create → address coords (info: lab has no geocoder key?)', null, `${ev(b)} coords=${id ? sql(`select coalesce(address_lat::text,'null')||','||coalesce(address_lng::text,'null')||' city='||coalesce(city_id::text,'null') from bookings where id=${id}`) : '-'}`);
  }

  // ── MQA-48 (dd5e520): scheduledAt offset forms, format vs past errors, availability conflict ──
  if (on('booktz')) {
    const mk = (s) => req('POST', '/api/v1/bookings', { token: C, body: { serviceId: svc, scheduledAt: s, district: 'Quận 1', ward: 'Bến Nghé', addressLine: '12 Lê Lợi', notes: 'rt2-tz', paymentMethod: 'cash', idempotencyKey: randomUUID() } });
    const stored = (id) => sql(`select to_char(scheduled_at at time zone 'UTC','YYYY-MM-DD HH24:MI') from bookings where id=${id}`);
    let tBooking = 0;
    for (const s of ['2026-12-21T09:00:00+07', '2026-12-21 09:00:00+07', '2026-12-21T09:00:00+0700', '2026-12-21 09:00:00+0700', '2026-12-21T09:00:00+07:00', '2026-12-21T02:00:00Z', '2026-12-21T09:00:00']) {
      const r = await mk(s);
      const id = r.data?.bookingId;
      const st = id ? stored(id) : '-';
      rec('booktz', `scheduledAt "${s}" → 201 stored 2026-12-21 02:00 UTC`, r.status === 201 && st === '2026-12-21 02:00', `${ev(r)} stored=${st}`);
      if (id) sql(`update bookings set status='CANCELLED' where id=${id}`);
    }
    // Conflict fixture inside the 60-day committed-jobs window (lib/availability/conflicts.ts toDays=60):
    // Mon 2026-11-30 09:00 VN sent as T + hour-only offset.
    {
      const r = await mk('2026-11-30T09:00:00+07');
      const id = r.data?.bookingId; const st = id ? stored(id) : '-';
      rec('booktz', 'conflict fixture "2026-11-30T09:00:00+07" → 201 stored 2026-11-30 02:00 UTC', r.status === 201 && st === '2026-11-30 02:00', `${ev(r)} stored=${st}`);
      if (id) tBooking = id;
    }
    for (const s of ['not-a-date', '2026-12-21T09:00:00+7', '2026-13-45T09:00:00+07', '21/12/2026 09:00']) {
      const n0 = sql('select count(*) from bookings');
      const r = await mk(s);
      rec('booktz', `unparseable "${s}" → 422 fields.scheduledAt "invalid format", no row`, r.status === 422 && /invalid format/i.test(String(r.json?.fields?.scheduledAt ?? '')) && sql('select count(*) from bookings') === n0, ev(r));
    }
    const past = await mk('2025-01-06T09:00:00+07');
    rec('booktz', 'valid PAST "2025-01-06T09:00:00+07" → 422 fields.scheduledAt "from now on" message', past.status === 422 && /hiện tại trở đi/.test(String(past.json?.fields?.scheduledAt ?? '')), ev(past));
    // Availability conflict on the booking created from the T+07 string (Mon 2026-12-21 09:00 VN).
    if (tBooking) {
      // short service (the bookable one can be 960 min, which legitimately overruns an 08:00–18:00 grid)
      const shortSvc = Number(sql(`select id from services where duration_minutes between 15 and 60 order by id limit 1`));
      sql(`update bookings set status='CONFIRMED', service_id=${shortSvc} where id=${tBooking}`);
      const job = Number(sql(`select id from jobs where booking_id=${tBooking} limit 1`)) || Number(sql(`insert into jobs(booking_id,status) values (${tBooking},'pending') returning id`).split('\n')[0]);
      sql(`update jobs set tasker_id=1, status='pending' where id=${job}`);
      const full = [{ start: 0, end: 1440 }];
      const grid = (mon) => ({ 0: full, 1: mon, 2: full, 3: full, 4: full, 5: full, 6: full });
      const has = (r) => (r.data?.conflicts ?? []).map(String).includes(String(job));
      const w1 = await req('PUT', '/api/v1/tasker/availability/weekly', { token: P, body: { force: false, days: grid([{ start: 480, end: 1080 }]) } });
      rec('booktz', `conflict check: Mon 08:00–18:00 covers job ${job} (T+07 booking, Mon 09:00 VN) → not a conflict`, w1.status === 200 && !has(w1), ev(w1));
      const w2 = await req('PUT', '/api/v1/tasker/availability/weekly', { token: P, body: { force: false, days: grid([{ start: 120, end: 150 }]) } });
      rec('booktz', `conflict check: Mon 02:00–02:30 only → saved:false, conflicts include job ${job}`, w2.status === 200 && w2.data?.saved === false && has(w2), ev(w2));
      await req('PUT', '/api/v1/tasker/availability/weekly', { token: P, body: { force: true, days: {} } });
      sql(`delete from tasker_availability where tasker_id=1 and specific_date is null`);
      sql(`update jobs set status='cancelled' where id=${job}`);
      sql(`update bookings set status='CANCELLED' where id=${tBooking}`);
    } else rec('booktz', 'conflict check skipped (T+07 booking not created)', false, '');
  }

  // ── MQA-40 (b): insurance fund never negative ──
  if (on('fund')) {
    const bal0 = sql(`select balance_vnd from wallets where owner_type='kyco_insurance'`);
    sql(`update wallets set balance_vnd=100000 where owner_type='kyco_insurance'`);
    await stepUp(A, ACC.admin[1]);
    const n0 = sql('select count(*) from insurance_fund_withdrawals');
    const r = await req('POST', '/api/admin/v1/insurance-fund', { token: A, body: { amountVnd: 200000, reason: 'rt2 QA fund floor' }, headers: { 'Idempotency-Key': key() } });
    const bal = sql(`select balance_vnd from wallets where owner_type='kyco_insurance'`);
    rec('fund', 'withdraw 200,000 from a 100,000 fund → 409, balance unchanged, no row', r.status === 409 && Number(bal) === 100000 && sql('select count(*) from insurance_fund_withdrawals') === n0, `${ev(r)} balance=${bal}`);
    const r2 = await req('POST', '/api/admin/v1/insurance-fund', { token: A, body: { amountVnd: 100000, reason: 'rt2 QA exact balance' }, headers: { 'Idempotency-Key': key() } });
    rec('fund', 'withdraw exactly the balance → 200, balance 0', r2.status === 200 && Number(sql(`select balance_vnd from wallets where owner_type='kyco_insurance'`)) === 0, ev(r2));
    sql(`update wallets set balance_vnd=${Number(bal0)} where owner_type='kyco_insurance'`);
  }

  // ── VRF-5: anonymous burst on public pages must not 500 ──
  if (on('vrf5')) {
    const pages = ['/vi', '/vi/services', '/vi/faqs', '/vi/locations', '/vi/signin', '/vi/taskers/1', '/vi/about'];
    const counts = {};
    for (let i = 0; i < 45; i++) {
      const p = pages[i % pages.length];
      const r = await fetch(ORIGIN + p, { redirect: 'manual', headers: { 'X-Forwarded-For': '203.0.113.7' } });
      counts[r.status] = (counts[r.status] ?? 0) + 1;
      if (r.status >= 500) { const t = await r.text(); rec('vrf5', `500 on ${p}`, false, t.slice(0, 160)); }
      else await r.arrayBuffer();
    }
    rec('vrf5', '45 anonymous public page loads from one IP → no 5xx', !Object.keys(counts).some((s) => Number(s) >= 500), JSON.stringify(counts));
  }

  // ── MQA-51 / 52 / 53 helpers (e4e0a28 / 1359903) ──
  const UUIDISH = /^[A-Za-z0-9._:-]{8,128}$/;
  const SERVER_LOG = process.env.SERVER_LOG || '';
  const logSize = () => { try { return fs.statSync(SERVER_LOG).size; } catch { return 0; } };
  const logSince = async (off) => {
    await sleep(700);
    let t = '';
    try { const fd = fs.openSync(SERVER_LOG, 'r'); const n = fs.statSync(SERVER_LOG).size - off; const b = Buffer.alloc(Math.max(0, n)); fs.readSync(fd, b, 0, b.length, off); fs.closeSync(fd); t = b.toString('utf8'); } catch { /* none */ }
    return t.split('\n').filter((l) => l.includes('"event":"api_error"')).map((l) => { try { return JSON.parse(l.slice(l.indexOf('{'))); } catch { return { raw: l }; } });
  };
  const clearFetchCache = () => fs.rmSync(`${WT}/.next/cache/fetch-cache`, { recursive: true, force: true });
  const run = (cmd, args, opts) => new Promise((resolve) => {
    const ch = spawn(cmd, args, opts); let out = '', err = '';
    ch.stdout.on('data', (d) => { out += d; }); ch.stderr.on('data', (d) => { err += d; });
    ch.on('close', (code) => resolve({ code, out, err }));
  });
  // real lab seed (DATABASE_URL from .env.local, exactly like rebuild-qa-db.sh)
  const runSeed = async (args = []) => {
    const r = await run('bash', ['-c', 'set -a; . ./.env.local; set +a; exec npx tsx scripts/seed-qa-money-fixtures.ts "$@"', '_', ...args], { cwd: WT, env: process.env });
    let j = null; try { j = JSON.parse(r.out); } catch { /* not json */ }
    clearFetchCache();
    return { ...r, json: j };
  };
  const errOf = (r) => r.json?.traceId ?? r.json?.error?.traceId ?? null;
  const adminUserId = Number(sql(`select id from users where email=${lit(ACC.admin[0])}`));

  // ── MQA-51: x-trace-id on every /api response; client x-request-id ignored; error traceId = header ──
  if (on('trace')) {
    const Q = T.qamoney;
    const samples = [
      ['v1 GET 2xx', 'GET', '/api/v1/me', { token: C }, 200],
      ['v1 GET list 2xx', 'GET', '/api/v1/bookings?page=1&limit=5', { token: C }, 200],
      ['v1 POST 2xx (step-up)', 'POST', '/api/v1/auth/step-up', { token: A, body: { method: 'password', password: ACC.admin[1] } }, 200],
      ['admin GET 2xx', 'GET', '/api/admin/v1/disputes', { token: A }, 200],
      ['public GET 2xx', 'GET', `/api/v1/services/${svc}`, {}, 200],
      ['public GET plans 2xx', 'GET', '/api/v1/plans', {}, 200],
      ['401 no token', 'GET', '/api/v1/bookings', {}, 401],
      ['404 unknown service', 'GET', '/api/v1/services/99999999', {}, 404],
      ['404 foreign/unknown admin dispute', 'GET', '/api/admin/v1/disputes/99999999', { token: A }, 404],
      ['422 validation (address empty line)', 'POST', '/api/v1/addresses', { token: C, body: { label: 'x', line: '', district: 'Quận 1', ward: 'Bến Nghé', city: 'Hồ Chí Minh' } }, 422],
      ['409 customer cancel QA-MONEY-PAY-UNSETTLED booking', 'POST', `/api/v1/bookings/${FIX?.bookings?.unsettled}/cancel`, { token: Q, body: { reasonCode: 'other' }, headers: { 'Idempotency-Key': key('rt2-409') } }, 409],
    ];
    const seen = new Set();
    for (const [name, m, path, o, want] of samples) {
      const r = await req(m, path, o);
      const okHdr = !!r.trace && UUIDISH.test(r.trace) && !seen.has(r.trace);
      seen.add(r.trace);
      const isErr = r.status >= 400;
      const bodyOk = !isErr || errOf(r) === r.trace;
      rec('trace', `${name} → ${want}, x-trace-id present${isErr ? ', body traceId = header' : ''}`, r.status === want && okHdr && bodyOk, `HTTP ${r.status} hdr=${r.trace} body=${errOf(r) ?? '-'} ${r.json?.code ?? ''}`);
    }
    // client-sent x-request-id must be ignored (fresh, server-assigned id)
    for (const [name, m, path, o] of [['2xx', 'GET', '/api/v1/me', { token: C }], ['401', 'GET', '/api/v1/bookings', {}], ['404', 'GET', '/api/v1/services/99999999', {}]]) {
      const spoof = `rt2-spoof-${randomUUID()}`;
      const r = await req(m, path, { ...o, headers: { 'x-request-id': spoof } });
      rec('trace', `client x-request-id ignored (${name})`, !!r.trace && r.trace !== spoof && errOf(r) !== spoof, `HTTP ${r.status} sent=${spoof} hdr=${r.trace} body=${errOf(r) ?? '-'}`);
    }
    // routes that may lack the header (not withApiRoute / matcher-excluded image extensions). INFO unless money.
    const extra = [
      ['GET', '/api/payment/vnpay/ipn', true], ['POST', '/api/payment/momo/ipn', true], ['GET', '/api/payment/vnpay/return', true],
      ['GET', '/api/payment/momo/return', true], ['GET', '/api/payment/return', true], ['GET', '/api/payment/status?id=1', true],
      ['POST', '/api/payment/vnpay/querydr', true], ['POST', '/api/cron/payment-reconcile', true], ['POST', '/api/cron/wallet-reconcile-daily', true],
      ['GET', '/api/health', false], ['GET', '/api/auth/session', false], ['GET', '/api/neighborhoods', false],
      ['GET', '/api/media/local/rt2/x.png', false], ['GET', '/api/media/local/rt2/x.webp', false], ['GET', '/api/reviews', false],
      ['GET', '/api/v1/no-such-route', false],
    ];
    const missing = [];
    for (const [m, path, money] of extra) {
      await sleep(900);   // anonymous limiter
      const res = await fetch(ORIGIN + path, { method: m, redirect: 'manual', headers: m === 'POST' ? { 'Content-Type': 'application/json' } : {}, body: m === 'POST' ? '{}' : undefined });
      await res.arrayBuffer();
      const t = res.headers.get('x-trace-id');
      if (!t) missing.push(`${m} ${path} (${res.status})`);
      rec('trace', `${m} ${path} carries x-trace-id`, t ? true : money ? false : null, `HTTP ${res.status} hdr=${t ?? 'NONE'}${money ? ' [money]' : ''}`);
    }
    rec('trace', 'routes without x-trace-id', null, missing.join('; ') || 'none');
    // MQA-54 — legacy POST /api/signup (not withApiRoute) with a JSON body: 500 + an unkeyed raw log line.
    // MQA-55 — unmatched /api/v1 + /api/admin/v1 paths answer the Next HTML 404 page, not the envelope.
    // INFO until fixed; SIGNUP_FIX=1 / UNKNOWN_ROUTE_FIX=1 assert.
    {
      const off = logSize();
      const res = await fetch(ORIGIN + '/api/signup', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: 'rt2-mqa54@qa.local', password: 'x' }) });
      const t = res.headers.get('x-trace-id'); const txt = await res.text();
      const raw = SERVER_LOG ? (await (async () => { await sleep(700); try { const b = fs.readFileSync(SERVER_LOG); return b.subarray(off).toString('utf8'); } catch { return ''; } })()) : '';
      const ok = res.status >= 400 && res.status < 500;
      rec('trace', 'MQA-54 POST /api/signup JSON body → 4xx (not 500)', process.env.SIGNUP_FIX ? ok : (ok || null),
        `HTTP ${res.status} hdr=${t} ${txt.slice(0, 60).replace(/\s+/g, ' ')} | log: ${raw.split('\n').filter((l) => l.trim() && !/^\s+at /.test(l)).join(' / ').slice(0, 160) || '(none)'} | traceId in log: ${!!t && raw.includes(t)}`);
      for (const p of ['/api/v1/no-such-route', '/api/admin/v1/no-such-route']) {
        await sleep(900);
        const r = await req('GET', p, { token: p.includes('admin') ? A : C });
        const env = r.status === 404 && r.json?.code === 'NOT_FOUND' && errOf(r) === r.trace;
        rec('trace', `MQA-55 GET ${p} → 404 envelope`, process.env.UNKNOWN_ROUTE_FIX ? env : (env || null), `HTTP ${r.status} hdr=${r.trace} ${r.json ? 'json ' + r.json.code : 'non-JSON ' + r.text.slice(0, 40).replace(/\s+/g, ' ')}`);
      }
    }
  }

  // ── MQA-52: error log by declared severity (needs SERVER_LOG = the next start stdout/stderr file) ──
  if (on('errlog')) {
    if (!SERVER_LOG || !fs.existsSync(SERVER_LOG)) rec('errlog', 'SERVER_LOG not set — skipped', null, '');
    else {
      const s0 = await runSeed(['--clearing=0']);
      rec('errlog', 'seed --clearing=0', s0.code === 0 && s0.json?.wallets?.kyco_clearing === 0, `exit ${s0.code} clearing=${s0.json?.wallets?.kyco_clearing}`);
      try {
        const su = await stepUp(A, ACC.admin[1]);
        let off = logSize();
        const r = await req('POST', '/api/admin/v1/payments/refunds', { token: A, body: { paymentId: FIX?.payments?.unsettled, amountVnd: 10000, reason: 'rt2 MQA-52 critical log' }, headers: { 'Idempotency-Key': key('rt2-52') } });
        const lines = await logSince(off);
        const mine = lines.filter((l) => l.traceId === r.trace);
        const L = mine[0] ?? {};
        rec('errlog', '409 INSUFFICIENT_CLEARING_BALANCE (clearing 0)', r.status === 409 && r.json?.code === 'INSUFFICIENT_CLEARING_BALANCE' && errOf(r) === r.trace, `step-up ${su} ${ev(r)} hdr=${r.trace}`);
        rec('errlog', '→ exactly one log line, level critical, traceId = header, code, status, route, actorId',
          lines.length === 1 && mine.length === 1 && L.level === 'critical' && L.code === 'INSUFFICIENT_CLEARING_BALANCE' && L.status === 409
            && L.route === 'POST /api/admin/v1/payments/refunds' && L.actorId === adminUserId,
          `${lines.length} api_error line(s): ${JSON.stringify(L).slice(0, 300)} (admin users.id=${adminUserId})`);
        // ordinary 4xx → silent
        off = logSize();
        const v = await req('POST', '/api/v1/addresses', { token: C, body: { label: 'x', line: '', district: 'Quận 1', ward: 'Bến Nghé', city: 'Hồ Chí Minh' } });
        const n4 = await req('GET', '/api/v1/services/99999999');
        const n4b = await req('GET', '/api/admin/v1/disputes/99999999', { token: A });
        const quiet = await logSince(off);
        rec('errlog', 'validation 422 + 404 (public, admin) → no log line', v.status === 422 && n4.status === 404 && n4b.status === 404 && quiet.length === 0,
          `422 ${v.trace} / 404 ${n4.trace} / 404 ${n4b.trace} → ${quiet.length} line(s) ${JSON.stringify(quiet).slice(0, 200)}`);
        // 5xx → a line (lab-only BEFORE INSERT trigger on addresses forces a DB error; dropped right after)
        sql(`create or replace function rt2_force_5xx() returns trigger language plpgsql as $f$ begin raise exception 'rt2 lab forced 5xx'; end $f$; drop trigger if exists rt2_force_5xx on addresses; create trigger rt2_force_5xx before insert on addresses for each row execute function rt2_force_5xx()`);
        try {
          off = logSize();
          const f = await req('POST', '/api/v1/addresses', { token: C, body: { label: 'rt2 5xx', line: '1 Lab', district: 'Quận 1', ward: 'Bến Nghé', city: 'Hồ Chí Minh' } });
          const l5 = (await logSince(off)).filter((l) => l.traceId === f.trace);
          rec('errlog', 'forced 5xx → one log line keyed by the returned traceId', f.status >= 500 && errOf(f) === f.trace && l5.length === 1 && l5[0].status === f.status && l5[0].route === 'POST /api/v1/addresses',
            `${ev(f)} hdr=${f.trace} lines=${JSON.stringify(l5).slice(0, 260)}`);
        } finally {
          sql('drop trigger if exists rt2_force_5xx on addresses; drop function if exists rt2_force_5xx()');
        }
      } finally {
        const s1 = await runSeed([]);
        rec('errlog', 'seed restored (clearing 1,000,000)', s1.code === 0 && s1.json?.wallets?.kyco_clearing === 1000000, `exit ${s1.code}`);
      }
    }
  }

  // ── MQA-53: seed lab guard, dispute reopen, cancellable pair ──
  if (on('seed')) {
    // (a) guard: fake env only; a local listener proves no connection/query is attempted
    let conns = 0;
    const srv = net.createServer((s) => { conns++; s.destroy(); });
    await new Promise((r) => srv.listen(0, '0.0.0.0', r));
    const port = srv.address().port;
    const lan = Object.values(os.networkInterfaces()).flat().find((i) => i && i.family === 'IPv4' && !i.internal)?.address;
    const fakes = [
      `postgres://qa:fake@127.0.0.1:${port}/kyco_latest`,
      `postgres://qa:fake@127.0.0.1:${port}/kyco_qa_prod_mirror`,
      `postgres://qa:fake@127.0.0.1:${port}/kyco`,
      `postgres://qa:fake@127.0.0.1:${port}/KYCO_WAPI_UPPER`,
      `postgres://qa:fake@127.0.0.1:${port}/kyco_wapi_x-y`,
      ...(lan ? [`postgres://qa:fake@${lan}:${port}/kyco_wapi_mobileqa`] : []),
      `postgres://qa:fake@db.example.invalid:${port}/kyco_wapi_mobileqa`,
      `postgres://qa:fake@localhost/kyco_wapi_mobileqa?host=/cloudsql/proj:region:inst`,
    ];
    for (const url of fakes) {
      const before = conns;
      const r = await run('npx', ['tsx', 'scripts/seed-qa-money-fixtures.ts'], { cwd: WT, env: { PATH: process.env.PATH, HOME: process.env.HOME, DATABASE_URL: url } });
      await sleep(200);
      rec('seed', `guard refuses ${url.replace(/:fake@/, ':***@')}`, r.code === 2 && /refusing to run/.test(r.err) && conns === before, `exit ${r.code} conns=${conns - before} ${r.err.trim().split('\n').pop().slice(0, 140)}`);
    }
    srv.close();
    // (b) a resolved [QA-MONEY] dispute is reopened by a re-run
    const dA = FIX?.disputes?.a ?? Number(sql(`select id from disputes where description='[QA-MONEY] dispute A'`));
    await stepUp(A, ACC.admin[1]);
    const rv = await req('POST', `/api/admin/v1/disputes/${dA}`, { token: A, body: { resolutionType: 'dismissed', notes: 'rt2 MQA-53 reopen' }, headers: { 'Idempotency-Key': key() } });
    const st1 = sql(`select status from disputes where id=${dA}`);
    rec('seed', `resolve [QA-MONEY] dispute A (#${dA})`, rv.status === 200 && st1 !== 'open', `${ev(rv)} status=${st1}`);
    const s2 = await runSeed([]);
    const row = sql(`select d.status||'|'||coalesce(d.resolution_type,'NULL')||'|'||coalesce(d.resolved_at::text,'NULL')||'|'||b.status from disputes d join bookings b on b.id=d.booking_id where d.id=${dA}`);
    rec('seed', 're-run reopens it (open, outcome/resolved_at cleared, booking IN_DISPUTE)', s2.code === 0 && row === 'open|NULL|NULL|IN_DISPUTE', `exit ${s2.code} ${row}`);
    // (c) cancellable PENDING VNPay booking: customer cancel → 200, a re-run creates a fresh pair
    const cb = s2.json?.bookings?.cancellable;
    const pre = sql(`select status||'|'||coalesce(notes,'') from bookings where id=${cb}`);
    const c1 = await req('POST', `/api/v1/bookings/${cb}/cancel`, { token: T.qamoney, body: { reasonCode: 'other', reasonText: 'rt2 MQA-53' }, headers: { 'Idempotency-Key': key('rt2-53') } });
    const post = sql(`select status from bookings where id=${cb}`);
    const rf = sql(`select count(*)||' rows '||coalesce(string_agg(status||':'||amount_vnd,','),'') from refunds where payment_id=${s2.json?.payments?.cancellable}`);
    rec('seed', `customer cancel ${pre} → 200 (Idempotency-Key)`, c1.status === 200 && post === 'CANCELLED', `${ev(c1)} booking=${post} refunds=${rf}`);
    const s3 = await runSeed([]);
    const nb = s3.json?.bookings?.cancellable;
    const nrow = nb ? sql(`select b.status||'|'||b.notes||'|'||p.provider_tx_id||'|'||p.status from bookings b join payments p on p.id=${s3.json.payments.cancellable} where b.id=${nb}`) : '-';
    rec('seed', 're-run creates a fresh cancellable pair', s3.code === 0 && nb && nb !== cb && /^PENDING\|\[QA-MONEY\] cancellable #\d+\|QA-MONEY-PAY-CANCELLABLE-\d+\|paid$/.test(nrow), `old=${cb} new=${nb} ${nrow}`);
    if (s3.json) fs.writeFileSync(process.env.QA_MONEY_FIXTURES || new URL('./.qa-money-fixtures.json', import.meta.url).pathname, JSON.stringify(s3.json, null, 2));
  }

  // ════════ fe-audit sync (feat/fe-audit ≥ ac0d5e5): MQA-58 KYC, Z2 pool, FE-06 work window, data export, MQA-56/57 ════════
  const GCS = process.env.GCS_API_ENDPOINT || 'http://localhost:4443';
  const BUCKET = process.env.GCS_BUCKET || 'kyco-mqa-media';
  const gcsList = async (prefix = '') => {
    const r = await fetch(`${GCS}/storage/v1/b/${BUCKET}/o?prefix=${encodeURIComponent(prefix)}`);
    const j = await r.json().catch(() => ({}));
    return (j.items ?? []).map((o) => ({ name: o.name, contentType: o.contentType, size: Number(o.size) }));
  };
  const gcsPut = (name, body, contentType) => fetch(`${GCS}/upload/storage/v1/b/${BUCKET}/o?uploadType=media&name=${encodeURIComponent(name)}`, { method: 'POST', headers: { 'Content-Type': contentType }, body });
  const envLocal = Object.fromEntries(fs.readFileSync(`${WT}/.env.local`, 'utf8').split('\n').filter((l) => /^[A-Z_]+=/.test(l)).map((l) => { const i = l.indexOf('='); return [l.slice(0, i), l.slice(i + 1).replace(/^['"]|['"]$/g, '')]; }));
  const crypto = await import('node:crypto');
  // ── fixtures: real images (generated), HTML/SVG renamed .png (padded past 10 KB so only the TYPE fails), 134 B PNG ──
  const FX = (() => {
    const pad = (s) => Buffer.from(s + ' '.repeat(Math.max(0, 12 * 1024 - s.length)));
    const html = pad('<html><body><h1>rt2</h1><script>alert(document.domain)</script></body></html><!--') ;
    const svg = pad('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg><!--');
    // 1×1 PNG padded with a tEXt chunk to exactly 134 bytes (valid PNG magic, < 10 KB)
    const crc32 = (b) => { let c, crc = 0xffffffff; for (const x of b) { c = (crc ^ x) & 0xff; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crc = (crc >>> 8) ^ c; } return (crc ^ 0xffffffff) >>> 0; };
    const base = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
    const iend = base.subarray(base.length - 12);
    const textLen = 134 - base.length - 12;
    const data = Buffer.concat([Buffer.from('tEXt'), Buffer.from('c\0' + 'x'.repeat(textLen - 2))]);
    const len = Buffer.alloc(4); len.writeUInt32BE(textLen); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(data));
    const tiny = Buffer.concat([base.subarray(0, base.length - 12), len, data, crc, iend]);
    const dir = process.env.RT2_FIXTURES || '/tmp/claude-1000/-home-bi-w-AppDroid1-ori/e83cad69-666e-4383-b5b7-0d5045b1a7d0/scratchpad/fx';
    const rd = (f) => { try { return fs.readFileSync(`${dir}/${f}`); } catch { return null; } };
    const pdf = Buffer.concat([Buffer.from('%PDF-1.4\n%rt2\n'), Buffer.alloc(11 * 1024, 0x20), Buffer.from('\n%%EOF\n')]);
    return { html, svg, tiny, jpeg: rd('real.jpg'), png: rd('real.png'), webp: rd('real.webp'), pdf };
  })();
  const blob = (buf, type = 'image/png') => new Blob([buf], { type });
  const BAD = [['html-as-png', FX.html, 'unsupported-mime'], ['svg-as-png', FX.svg, 'unsupported-mime'], ['134B-png', FX.tiny, 'too-small']];
  const kycHdrOk = (r, wantInline) => {
    const h = r.headers; const cd = h.get('content-disposition') ?? ''; const csp = h.get('content-security-policy') ?? '';
    const ok = h.get('x-content-type-options') === 'nosniff' && /sandbox/.test(csp) && /no-store/.test(h.get('cache-control') ?? '')
      && (wantInline ? /^inline/.test(cd) : /^attachment/.test(cd));
    return { ok, d: `HTTP ${r.status} ct=${h.get('content-type')} cd=${cd} nosniff=${h.get('x-content-type-options')} csp=${/sandbox/.test(csp) ? 'sandbox' : csp.slice(0, 40)} cc=${h.get('cache-control')}` };
  };
  const cookieJar = (cs) => [...new Map(cs.map((c) => c.split(';')[0]).map((kv) => [kv.split('=')[0], kv])).values()].join('; ');
  const webLogin = async (email, password) => {
    const w = lastLogin + LOGIN_GAP - Date.now(); if (w > 0) await sleep(w); lastLogin = Date.now();
    const c0 = await fetch(ORIGIN + '/api/auth/csrf'); const csrf = (await c0.json()).csrfToken; let cs = c0.headers.getSetCookie();
    const lg = await fetch(ORIGIN + '/api/auth/callback/credentials', { method: 'POST', redirect: 'manual', headers: { Cookie: cookieJar(cs), 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ csrfToken: csrf, email, password, json: 'true' }) });
    cs = [...cs, ...lg.headers.getSetCookie()]; const ck = cookieJar(cs);
    const sess = await (await fetch(ORIGIN + '/api/auth/session', { headers: { Cookie: ck } })).json().catch(() => null);
    return sess?.user ? ck : null;
  };
  // tok = Bearer token, or { cookie } for a web session
  const rawGet = (path, tok, extra = {}) => sleep(PACE).then(() => fetch(ORIGIN + path, { headers: { ...(tok?.cookie ? { Cookie: tok.cookie } : tok ? { Authorization: `Bearer ${tok}` } : {}), ...extra }, redirect: 'manual' }));

  if (on('kyc')) {
    if (!FX.jpeg || !FX.png || !FX.webp) rec('kyc', 'fixtures real.jpg/png/webp missing (RT2_FIXTURES)', false, '');
    rec('kyc', 'fixture sizes', null, `html=${FX.html.length} svg=${FX.svg.length} tiny=${FX.tiny.length} jpeg=${FX.jpeg?.length} png=${FX.png?.length} webp=${FX.webp?.length} pdf=${FX.pdf.length}`);
    // lab applicants: a fresh customer with a verified phone (upgrade door) and a fresh phone (public door)
    const bcrypt = createRequire(`${WT}/package.json`)('bcryptjs');
    const stamp = Date.now().toString().slice(-7);
    const upEmail = `rt2-upgrade-${stamp}@qa.local`, upPw = 'RetestQa12345!';
    sql(`insert into users (email,password_hash,name,role,is_active,token_version,phone,phone_verified_at) values (${lit(upEmail)},${lit(bcrypt.hashSync(upPw, 10))},'RT2 Upgrade','customer',true,0,'+8498${stamp}',now())`);
    const upId = Number(sql(`select id from users where email=${lit(upEmail)}`));
    const lu = await req('POST', '/api/v1/auth/login', { body: { email: upEmail, password: upPw } });
    const U = lu.data?.accessToken;
    rec('kyc', 'login fresh customer (upgrade applicant)', !!U, `users.id=${upId} ${U ? '' : ev(lu)}`);
    const pubPhone = (n) => `+849${stamp}${n}`;   // +84 + 9 digits (lib/otp normalizePhone)
    // public door verifies an OTP first (purpose register): lab-only challenge row hashed with the lab pepper
    const otpFor = (phone) => {
      const code = String(100000 + Math.floor(Math.random() * 899999));
      const h = crypto.createHmac('sha256', envLocal.ZALO_OTP_HASH_PEPPER || '').update(`${code}:${phone}:register`, 'utf8').digest('hex');
      sql(`insert into otp_challenges (phone,code_hash,expires_at,purpose) values (${lit(phone)},${lit(h)},now()+interval '5 minutes','register')`);
      return code;
    };
    const docsCount = (uid) => Number(sql(`select count(*) from kyc_documents where user_id=${uid}`));
    const objCount = async () => (await gcsList()).length;
    const files3 = (fd, bad) => { // two real JPEGs + the probe in `selfie`
      fd.set('cccd_front', blob(FX.jpeg, 'image/jpeg'), 'front.jpg'); fd.set('cccd_back', blob(FX.jpeg, 'image/jpeg'), 'back.jpg');
      fd.set('selfie', blob(bad, 'image/png'), 'selfie.png');
    };
    const profile = (fd) => { fd.set('name', 'RT2 KYC'); fd.set('city', 'Hồ Chí Minh'); fd.set('district', 'Quận 1'); };
    const custId = Number(sql(`select id from users where email=${lit(ACC.customer[0])}`));
    // web /api/kyc/upload (the old form door) — must not exist any more (or must share the validator)
    // /api/* outside v1 is cookie-gated by middleware (a Bearer gets 401) → admin/customer web sessions
    const AW = await webLogin(...ACC.admin); const CW = await webLogin(...ACC.customer);
    rec('kyc', 'admin + customer web cookie sessions', !!AW && !!CW, `admin=${!!AW} customer=${!!CW}`);
    {
      const fd = new FormData(); fd.set('cccd_front', blob(FX.html), 'a.png');
      await sleep(PACE);
      const r = await fetch(ORIGIN + '/api/kyc/upload', { method: 'POST', headers: { Cookie: CW ?? '', Origin: ORIGIN, Accept: 'application/json' }, body: fd, redirect: 'manual' });
      const t = await r.text();
      // no upload handler any more: /api/kyc/[id] (GET only) answers 405 for POST /api/kyc/upload
      rec('kyc', 'web /api/kyc/upload (customer cookie) gone → 404/405, no 4th door', [404, 405].includes(r.status), `HTTP ${r.status} ${t.slice(0, 100) || '(empty body)'}`);
    }
    // three doors × [html, svg, 134 B]; signup limiter = 3/60 s per door → one probe per door per round, 21 s apart
    let round = 0;
    for (const [label, bytes, reason] of BAD) {
      if (round++) await sleep(21_000);
      const o0 = await objCount();
      // (a) /v1/kyc/upload (customer Bearer)
      {
        const d0 = docsCount(custId);
        const fd = new FormData(); fd.set('cccd_front', blob(bytes), 'cccd_front.png');
        const r = await req('POST', '/api/v1/kyc/upload', { token: C, raw: fd });
        const fieldOk = r.status === 422 && Object.values(r.json?.fields ?? {}).includes(reason);
        const perFile = r.status === 200 && r.data?.results?.[0]?.ok === false && r.data?.results?.[0]?.reason === reason;
        // MQA-59: this door answers 200 {results:[{ok:false,reason}]} (partial-success contract, same as 8877d67);
        // INFO until fixed, KYC_UPLOAD_FIX=1 asserts the 422 field contract of the other doors.
        rec('kyc', `/v1/kyc/upload ${label} → 422 field ${reason}`, process.env.KYC_UPLOAD_FIX ? fieldOk : (fieldOk || null), `${ev(r)}${perFile ? ' [200 per-file results ok:false reason=' + reason + ']' : ''}`);
        rec('kyc', `/v1/kyc/upload ${label} → rejected with reason ${reason} (422 field or per-file result)`, fieldOk || perFile, '');
        rec('kyc', `/v1/kyc/upload ${label} → nothing stored`, docsCount(custId) === d0, `kyc_documents ${d0}→${docsCount(custId)}`);
      }
      // (b) public /v1/become-tasker
      {
        const phone = pubPhone(round);
        const fd = new FormData(); fd.set('phone', phone); fd.set('otp_code', otpFor(phone)); profile(fd); files3(fd, bytes);
        const r = await req('POST', '/api/v1/become-tasker', { raw: fd });
        rec('kyc', `public /v1/become-tasker ${label} → 422 selfie=${reason}`, r.status === 422 && r.json?.fields?.selfie === reason, ev(r));
        const u = Number(sql(`select count(*) from users where phone=${lit(phone)}`));
        const objs = await gcsList(`collaborator-kyc/pending-${phone.replace(/\D/g, '')}/`);
        rec('kyc', `public /v1/become-tasker ${label} → no user, no object`, u === 0 && objs.length === 0, `users=${u} objects=${objs.map((o) => o.name).join(',') || 0}`);
      }
      // (c) /v1/become-tasker/upgrade (signed-in customer)
      if (U) {
        const d0 = docsCount(upId);
        const ob0 = (await gcsList(`collaborator-kyc/user-${upId}/`)).length;   // the fake GCS outlives DB rebuilds
        const fd = new FormData(); profile(fd); files3(fd, bytes);
        const r = await req('POST', '/api/v1/become-tasker/upgrade', { token: U, raw: fd });
        rec('kyc', `/v1/become-tasker/upgrade ${label} → 422 selfie=${reason}`, r.status === 422 && r.json?.fields?.selfie === reason, ev(r));
        const role = sql(`select role from users where id=${upId}`);
        rec('kyc', `/v1/become-tasker/upgrade ${label} → nothing stored, still customer`, docsCount(upId) === d0 && role === 'customer' && (await gcsList(`collaborator-kyc/user-${upId}/`)).length === ob0, `docs ${d0}→${docsCount(upId)} role=${role} objects ${ob0}→${(await gcsList(`collaborator-kyc/user-${upId}/`)).length}`);
      }
      rec('kyc', `bucket object count unchanged after ${label} round`, (await objCount()) === o0, `${o0}→${await objCount()}`);
    }
    // ── positive: real files on every door ──
    await sleep(21_000);
    const stored = {};
    {
      const fd = new FormData();
      fd.set('cccd_front', blob(FX.jpeg, 'text/html'), 'x.html');     // declared type/name are ignored
      fd.set('cccd_back', blob(FX.png, 'image/png'), 'b.png');
      fd.set('selfie', blob(FX.webp, 'image/webp'), 's.webp');
      fd.set('passport', blob(FX.pdf, 'application/pdf'), 'p.pdf');
      const r = await req('POST', '/api/v1/kyc/upload', { token: C, raw: fd });
      const res = r.data?.results ?? [];
      rec('kyc', '/v1/kyc/upload jpeg(declared text/html)+png+webp+pdf → 200, 4 stored', r.status === 200 && res.filter((x) => x.ok).length === 4, ev(r));
      for (const x of res.filter((x) => x.ok)) stored[x.docKind] = { id: x.documentId, key: x.storageKey };
      const objs = (await gcsList(`customer-kyc/user-${custId}/`)).filter((o) => res.some((x) => x.ok && x.storageKey?.replace(/^kyc\//, 'customer-kyc/') === o.name));
      const fr = objs.find((o) => o.name.includes('cccd_front'));
      rec('kyc', '/v1/kyc/upload jpeg → customer-kyc/… image/jpeg (.jpg), not the declared type', !!fr && fr.contentType === 'image/jpeg' && /\.jpg$/.test(fr.name), JSON.stringify(objs.map((o) => `${o.name} ${o.contentType}`)));
    }
    {
      const phone = pubPhone(9);
      const fd = new FormData(); fd.set('phone', phone); fd.set('otp_code', otpFor(phone)); profile(fd); files3(fd, FX.jpeg);
      const r = await req('POST', '/api/v1/become-tasker', { raw: fd });
      const objs = await gcsList(`collaborator-kyc/pending-${phone.replace(/\D/g, '')}/`);
      rec('kyc', 'public /v1/become-tasker 3 real JPEGs → 200/201 {userId}', [200, 201].includes(r.status) && r.data?.userId > 0, ev(r));
      rec('kyc', 'public door objects under collaborator-kyc/pending-…/ as image/jpeg .jpg', objs.length === 3 && objs.every((o) => o.contentType === 'image/jpeg' && /\.jpg$/.test(o.name)), JSON.stringify(objs.map((o) => `${o.name} ${o.contentType}`)));
    }
    if (U) {
      const pre = new Set((await gcsList(`collaborator-kyc/user-${upId}/`)).map((o) => o.name));
      const fd = new FormData(); profile(fd); files3(fd, FX.jpeg);
      const r = await req('POST', '/api/v1/become-tasker/upgrade', { token: U, raw: fd });
      const objs = (await gcsList(`collaborator-kyc/user-${upId}/`)).filter((o) => !pre.has(o.name));
      rec('kyc', '/v1/become-tasker/upgrade 3 real JPEGs → 201 pending_tasker', r.status === 201 && r.data?.status === 'pending_tasker', ev(r));
      rec('kyc', 'upgrade door objects under collaborator-kyc/user-N/ as image/jpeg', objs.length === 3 && objs.every((o) => o.contentType === 'image/jpeg'), JSON.stringify(objs.map((o) => `${o.name} ${o.contentType}`)));
    }
    // ── legacy objects stored before the fix (HTML/SVG): served as attachment by every read door ──
    const legacyHtml = `kyc-pending/rt2-${stamp}/selfie.html`, legacySvg = `kyc-pending/rt2-${stamp}/cccd_back.svg`;
    await gcsPut(legacyHtml, FX.html, 'text/html'); await gcsPut(legacySvg, FX.svg, 'image/svg+xml');
    const lid = Number(sql(`insert into kyc_documents (user_id,doc_kind,storage_key,status) values (${custId},'selfie',${lit(legacyHtml)},'pending') returning id`).split('\n')[0]);
    const sid = Number(sql(`insert into kyc_documents (user_id,doc_kind,storage_key,status) values (${custId},'cccd_back',${lit(legacySvg)},'pending') returning id`).split('\n')[0]);
    const cases = [
      ['jpeg', stored.cccd_front, true], ['png', stored.cccd_back, true], ['webp', stored.selfie, true], ['pdf', stored.passport, false],
      ['legacy html', { id: lid, key: legacyHtml }, false], ['legacy svg', { id: sid, key: legacySvg }, false],
    ];
    for (const [label, doc, inline] of cases) {
      if (!doc) { rec('kyc', `read ${label}: no stored doc`, false, ''); continue; }
      // the stored key for customer docs is kyc/… (bucket object customer-kyc/…)
      for (const [door, path, tok] of [
        ['admin /api/kyc/file?key=', `/api/kyc/file?key=${encodeURIComponent(doc.key)}`, { cookie: AW }],
        ['admin /api/kyc/{id}', `/api/kyc/${doc.id}`, { cookie: AW }],
        ['owner /v1/kyc/file/{id}', `/api/v1/kyc/file/${doc.id}`, C],
      ]) {
        const r = await rawGet(path, tok);
        const h = kycHdrOk(r, inline);
        const ct = r.headers.get('content-type') ?? '';
        const typeOk = inline ? /^image\/(jpeg|png|webp)/.test(ct) : !/html|svg/.test(ct);
        rec('kyc', `${door} ${label} → 200 ${inline ? 'inline' : 'attachment'}, nosniff, sandbox CSP, no-store`, r.status === 200 && h.ok && typeOk, h.d);
        await r.arrayBuffer().catch(() => {});
      }
    }
    {
      const r = await rawGet(`/api/v1/kyc/file/${stored.cccd_front?.id}`, P2);
      rec('kyc', 'other user /v1/kyc/file/{id} → 404', r.status === 404, `HTTP ${r.status}`);
      for (const k of ['checkin/x.jpg', 'media/1/a.jpg', '../kyc/user-1/a.jpg']) {
        const r2 = await rawGet(`/api/kyc/file?key=${encodeURIComponent(k)}`, { cookie: AW });
        rec('kyc', `admin /api/kyc/file?key=${k} (non-KYC prefix) → 400`, r2.status === 400, `HTTP ${r2.status} ${(await r2.text()).slice(0, 80)}`);
      }
      const r3 = await rawGet(`/api/kyc/file?key=${encodeURIComponent(stored.cccd_front?.key ?? '')}`, { cookie: CW });
      rec('kyc', 'customer web cookie /api/kyc/file → 403', r3.status === 403, `HTTP ${r3.status}`);
      const r4 = await rawGet(`/api/kyc/${stored.cccd_front?.id}`, { cookie: CW });
      rec('kyc', 'owner (customer) web cookie /api/kyc/{id} own doc → 200 inline', r4.status === 200 && kycHdrOk(r4, true).ok, kycHdrOk(r4, true).d);
      const r5 = await rawGet(`/api/kyc/file?key=${encodeURIComponent(stored.cccd_front?.key ?? '')}`, A);
      rec('kyc', 'admin Bearer /api/kyc/file → 401 (cookie-gated web path; no mobile admin door)', r5.status === 401, `HTTP ${r5.status}`);
    }
    sql(`delete from kyc_documents where id in (${lid},${sid})`);
  }

  // ── Z2 pool privacy + taskerNetVnd (8edc05d) + FE-06 work window + ping → distanceKm ──
  if (on('pool') || on('window')) {
    const vnDay = (d) => new Date(Date.now() + 7 * 3600_000 + d * 86_400_000).toISOString().slice(0, 10);
    const mk = async (label, day, hhmm) => {
      const body = { serviceId: svc, scheduledAt: `${vnDay(day)}T${hhmm}:00`, district: 'Quận 1', ward: 'Bến Nghé', addressLine: `12 Lê Lợi rt2-${label}`, notes: `rt2-secret-note-${label}`, paymentMethod: 'cash', idempotencyKey: randomUUID() };
      const r = await req('POST', '/api/v1/bookings', { token: C, body });
      const bid = r.data?.bookingId;
      rec('pool', `create booking ${label}`, r.status === 201 && bid > 0, ev(r));
      if (bid) sql(`update bookings set address_lat=10.7769, address_lng=106.7009 where id=${bid}`);
      return bid;
    };
    const day = 4 + Math.floor(Math.random() * 15);
    const b1 = await mk('z2a', day, '09:00');
    const b2 = await mk('z2b', day, '15:00');
    const b3 = await mk('z2c-assigned', day + 2, '18:00');   // another day: no JOB_TIME_CONFLICT with the claim
    // let both taskers see the rows now (rank gate is not under test here)
    sql(`update jobs set pool_broadcasted_at=now() - interval '10 minutes' where booking_id in (${b1},${b2})`);
    const pingFresh = (tid) => Number(sql(`select count(*) from tasker_location_pings where tasker_id=${tid} and recorded_at >= now() - interval '24 hours'`)) > 0;
    const PT = Number(sql(`select id from taskers where user_account_id=(select id from users where email=${lit(ACC.tasker[0])})`));
    const checkPool = async (who, tok, tid, tag) => {
      const r = await req('GET', '/api/v1/tasker/jobs/pool', { token: tok });
      const rows = r.data?.pool ?? [];
      const mine = rows.filter((x) => [b1, b2].includes(x.bookingId));
      const leaks = rows.filter((x) => ['addressLine', 'notes', 'addressLat', 'addressLng'].some((k) => k in x));
      rec('pool', `${tag} ${who} pool rows: no addressLine/notes/addressLat/addressLng`, r.status === 200 && rows.length > 0 && leaks.length === 0, `HTTP ${r.status} rows=${rows.length} leaking=${leaks.length} keys=${Object.keys(rows[0] ?? {}).join(',')}`);
      rec('pool', `${tag} ${who} pool rows carry distanceKm`, rows.length > 0 && rows.every((x) => 'distanceKm' in x), '');
      const fresh = pingFresh(tid);
      const dk = mine.map((x) => x.distanceKm);
      rec('pool', `${tag} ${who} distanceKm ${fresh ? 'number (ping ≤24 h)' : 'null (no ping ≤24 h)'}`, mine.length >= 1 && dk.every((v) => fresh ? typeof v === 'number' && v >= 0 : v === null), `fresh=${fresh} distanceKm=${JSON.stringify(dk)}`);
      // 8edc05d — taskerNetVnd: server-computed JSON integer, 0 < net ≤ totalVnd for priced rows
      const netBad = (xs) => xs.filter((x) => (x.totalVnd ?? 0) > 0 && !(Number.isInteger(x.taskerNetVnd) && x.taskerNetVnd > 0 && x.taskerNetVnd <= x.totalVnd));
      const asg = r.data?.assigned ?? [];
      rec('pool', `${tag} ${who} pool+assigned taskerNetVnd integer, 0 < net ≤ totalVnd`, netBad(rows).length === 0 && netBad(asg).length === 0 && rows.some((x) => 'taskerNetVnd' in x),
        `pool=${rows.slice(0, 3).map((x) => `${x.jobId}:${x.taskerNetVnd}/${x.totalVnd}`).join(' ')} assigned=${asg.slice(0, 3).map((x) => `${x.jobId}:${x.taskerNetVnd}/${x.totalVnd}`).join(' ')} bad=${netBad(rows).length + netBad(asg).length}`);
      return mine;
    };
    // an admin-assigned job (dispatch_mode 'assigned') so `assigned` has a priced row to check
    if (b3) sql(`update jobs set dispatch_mode='assigned', tasker_id=${PT}, status='pending' where booking_id=${b3}`);
    // null-distance case: age tasker2's pings past 24 h (lab fixture) so it has no known position
    sql(`update tasker_location_pings set recorded_at = recorded_at - interval '25 hours' where tasker_id=${T2T} and recorded_at >= now() - interval '24 hours'`);
    const before = await checkPool('tasker', P, PT, 'pre-ping');
    await checkPool('tasker2', P2, T2T, 'pre-ping');
    const j1 = before.find((x) => x.bookingId === b1)?.jobId ?? Number(sql(`select id from jobs where booking_id=${b1}`));
    // a client-supplied net is ignored (query + body)
    {
      const r = await req('GET', '/api/v1/tasker/jobs/pool?taskerNetVnd=1&totalVnd=1', { token: P });
      const row = (r.data?.pool ?? []).find((x) => x.jobId === j1);
      const ref = before.find((x) => x.jobId === j1);
      rec('pool', 'query ?taskerNetVnd=1 has no effect', !!row && row.taskerNetVnd === ref?.taskerNetVnd, `${row?.taskerNetVnd} vs ${ref?.taskerNetVnd}`);
    }
    // claim → owner sees address + notes; another tasker 404
    const cl = await req('POST', `/api/v1/tasker/jobs/${j1}/claim`, { token: P });
    rec('pool', `claim job ${j1}`, cl.status === 200, ev(cl));
    const own = await req('GET', `/api/v1/tasker/jobs/${j1}`, { token: P });
    const ojs = JSON.stringify(own.data ?? {});
    rec('pool', 'owner GET /tasker/jobs/{id} shows addressLine + notes', own.status === 200 && ojs.includes('12 Lê Lợi rt2-z2a') && ojs.includes('rt2-secret-note-z2a'), `HTTP ${own.status} ${ojs.slice(0, 160)}`);
    const oth = await req('GET', `/api/v1/tasker/jobs/${j1}`, { token: P2 });
    rec('pool', 'tasker2 GET claimed job → 404 (no address)', oth.status === 404 && !JSON.stringify(oth.json).includes('rt2-z2a'), ev(oth));
    const asg = await req('GET', '/api/v1/tasker/jobs/pool', { token: P });
    const j3 = b3 ? Number(sql(`select id from jobs where booking_id=${b3}`)) : 0;
    const arow = (asg.data?.assigned ?? []).find((x) => x.jobId === j3);
    rec('pool', 'admin-assigned job in `assigned` with integer taskerNetVnd, 0 < net ≤ totalVnd', !!arow && Number.isInteger(arow.taskerNetVnd) && arow.taskerNetVnd > 0 && arow.taskerNetVnd <= arow.totalVnd, JSON.stringify(arow ?? {}).slice(0, 200));

    // ── FE-06 work window on j1 ──
    const setSched = (expr) => sql(`update bookings set scheduled_at=${expr} where id=${b1}`);
    const geo = { lat: 10.7769, lon: 106.7009, accuracyM: 10 };
    const st = await req('POST', `/api/v1/tasker/jobs/${j1}/start-tracking`, { token: P });
    rec('window', 'start-tracking', st.status === 201, ev(st));
    // a location ping via the tracking route (claimed job is 'active' + an open tracking session) → position ≤24 h
    {
      const r = await req('POST', `/api/v1/jobs/${j1}/location`, { token: P, body: { lat: 10.78, lng: 106.70, accuracy: 10 } });
      rec('pool', 'POST /v1/jobs/{id}/location ping (tracking route, en route)', [200, 201].includes(r.status), ev(r));
      // MQA-60: foreign job → 403 FORBIDDEN 'not your job' (checklist #4 wants 404). INFO until LOCATION_404_FIX=1.
      const rf = await req('POST', `/api/v1/jobs/${j1}/location`, { token: P2, body: { lat: 10.78, lng: 106.70 } });
      rec('pool', 'tasker2 ping on foreign job → 404 (checklist #4)', process.env.LOCATION_404_FIX ? rf.status === 404 : (rf.status === 404 || null), ev(rf));
      rec('pool', 'tasker2 ping on foreign job wrote nothing', Number(sql(`select count(*) from tasker_location_pings where job_id=${j1} and tasker_id=${T2T}`)) === 0, '');
      await checkPool('tasker', P, PT, 'post-ping');
    }
    const snap = () => sql(`select (select count(*) from tasker_check_ins where job_id=${j1})||'|'||(select status from jobs where id=${j1})||'|'||(select status from bookings where id=${b1})||'|'||(select count(*) from tasker_fines where tasker_id=${PT})`);
    const vnHm = (ms) => { const d = new Date(ms + 7 * 3600_000); const p = (n) => String(n).padStart(2, '0'); return `${p(d.getUTCHours())}:${p(d.getUTCMinutes())} ${p(d.getUTCDate())}/${p(d.getUTCMonth() + 1)}`; };
    {
      setSched(`now() - interval '2 hours 10 minutes'`);
      const s0 = snap();
      const r = await req('POST', `/api/v1/tasker/jobs/${j1}/check-in`, { token: P, body: geo });
      rec('window', 'check-in 2h10m after scheduledAt → 409 CHECKIN_TOO_LATE, nothing written', r.status === 409 && r.json?.code === 'CHECKIN_TOO_LATE' && snap() === s0, `${ev(r)} ${r.json?.message ?? ''} snap ${s0}→${snap()}`);
    }
    {
      const schedMs = Date.now() + 3 * 3600_000;
      setSched(`to_timestamp(${schedMs / 1000})`);
      const s0 = snap();
      const r = await req('POST', `/api/v1/tasker/jobs/${j1}/check-in`, { token: P, body: geo });
      const opens = vnHm(schedMs - 30 * 60_000);
      rec('window', `check-in 3h before → 409 CHECKIN_TOO_EARLY, message has opening ${opens}, nothing written`, r.status === 409 && r.json?.code === 'CHECKIN_TOO_EARLY' && String(r.json?.message ?? '').includes(opens) && snap() === s0, `${ev(r)} msg=${r.json?.message} snap ${s0}→${snap()}`);
    }
    // admin override: staff without admin:dispatch:write → 403; customer → 403; admin + step-up → 201 + 1 audit row
    const auditN = () => Number(sql(`select count(*) from admin_audit where action='admin.job.work_window_override' and target_id='${j1}'`));
    const ov = (tok, body, k = key('rt2-ww')) => req('POST', `/api/admin/v1/jobs/${j1}/work-window-override`, { token: tok, body, headers: { 'Idempotency-Key': k } });
    {
      const a0 = auditN();
      const r1 = await ov(S, { kind: 'check_in', reason: 'rt2 staff no scope' });
      rec('window', 'override by staff without admin:dispatch:write → 403', r1.status === 403 && auditN() === a0, ev(r1));
      const r2 = await ov(C, { kind: 'check_in', reason: 'rt2 customer' });
      rec('window', 'override by customer → 403', r2.status === 403 && auditN() === a0, ev(r2));
      const r3 = await ov(A, { kind: 'lunch', reason: 'rt2 bad kind' });
      rec('window', 'override bad kind → 422 (or step-up first)', [422, 401, 403].includes(r3.status) && auditN() === a0, ev(r3));
      const sus = await stepUp(A, ACC.admin[1]);
      const r4 = await ov(A, { kind: 'check_in', reason: 'rt2 lab override check-in' });
      rec('window', 'override check_in (admin + step-up) → 201, exactly 1 audit row, expiresAt ≈ +6 h', r4.status === 201 && auditN() === a0 + 1 && Math.abs(Date.parse(r4.data?.expiresAt) - Date.now() - 6 * 3600_000) < 120_000, `step-up ${sus} ${ev(r4)} audit ${a0}→${auditN()}`);
      const r5 = await ov(A, { kind: 'check_in', reason: 'x' });
      rec('window', 'override reason < 5 chars → 422, no audit', r5.status === 422 && auditN() === a0 + 1, ev(r5));
    }
    {
      const r = await req('POST', `/api/v1/tasker/jobs/${j1}/check-in`, { token: P, body: geo });
      rec('window', 'check-in 3h early after override → 201, no late fine', r.status === 201 && r.data?.lateFine?.fine === 0, ev(r));
    }
    // photos (prereq for check-out): 2 before + 1 mid via request-upload → PUT → finalize
    const upload = async (category, name) => {
      const ru = await req('POST', '/api/v1/media/request-upload', { token: P, body: { category, entityType: 'booking', entityId: b1, fileName: name, mimeType: 'image/jpeg', sizeBytes: FX.jpeg.length } });
      if (!ru.data?.uploadUrl) { rec('window', `request-upload ${name}`, false, ev(ru)); return 0; }
      const put = await fetch(ru.data.uploadUrl, { method: 'PUT', headers: { 'Content-Type': ru.data.requiredContentType || 'image/jpeg' }, body: FX.jpeg });
      const fin = await req('POST', '/api/v1/media/finalize', { token: P, body: { mediaId: ru.data.assetId } });
      if (fin.status !== 200) rec('window', `finalize ${name}`, false, `PUT ${put.status} ${ev(fin)}`);
      return fin.status === 200 ? ru.data.assetId : 0;
    };
    const m1 = await upload('checkin', 'b1.jpg'), m2 = await upload('checkin', 'b2.jpg');
    const ph1 = await req('POST', `/api/v1/tasker/jobs/${j1}/photos`, { token: P, body: { slot: 'before', mediaIds: [m1, m2] } });
    const m3 = await upload('checkout', 'm1.jpg');
    const ph2 = await req('POST', `/api/v1/tasker/jobs/${j1}/photos`, { token: P, body: { slot: 'mid', mediaIds: [m3] } });
    rec('window', 'photos before x2 + mid x1', ph1.status === 200 && ph2.status === 200, `${ev(ph1)} | ${ev(ph2)}`);
    const coSnap = () => sql(`select (select count(*) from tasker_check_ins where job_id=${j1})||'|'||(select status from jobs where id=${j1})||'|'||(select status from bookings where id=${b1})||'|'||(select count(*) from location_sessions where job_id=${j1} and is_active)`);
    {
      const s0 = coSnap();
      const r = await req('POST', `/api/v1/tasker/jobs/${j1}/check-out`, { token: P, body: { lat: 10.7769, lng: 106.7009, accuracyM: 10 } });
      rec('window', 'check-out right after check-in → 409 CHECKOUT_TOO_EARLY, nothing written', r.status === 409 && r.json?.code === 'CHECKOUT_TOO_EARLY' && coSnap() === s0, `${ev(r)} msg=${r.json?.message} snap ${s0}→${coSnap()}`);
      const a0 = auditN();
      const o = await ov(A, { kind: 'check_out', reason: 'rt2 lab override check-out' });
      rec('window', 'override check_out → 201, +1 audit', o.status === 201 && auditN() === a0 + 1, ev(o));
      const r2 = await req('POST', `/api/v1/tasker/jobs/${j1}/check-out`, { token: P, body: { lat: 10.7769, lng: 106.7009, accuracyM: 10 } });
      rec('window', 'check-out after override → 200', r2.status === 200, ev(r2));
    }
    sql(`update jobs set status='closed' where (booking_id=${b2} and tasker_id is null) or booking_id=${b3 || 0}`);
  }

  // ── Data export (ae0cc41) ──
  if (on('export')) {
    const custId = Number(sql(`select id from users where email=${lit(ACC.customer[0])}`));
    const r0 = await req('POST', '/api/v1/data-export', { token: C, body: { notes: 'rt2 export' } });
    const xid = r0.data?.id;
    rec('export', 'customer POST /v1/data-export → 201 {id}', r0.status === 201 && xid > 0, ev(r0));
    const audit = () => Number(sql(`select count(*) from admin_audit where action='admin.data_export.fulfil' and target_id='${xid}'`));
    const f1 = await req('POST', `/api/admin/v1/data-export-requests/${xid}/fulfil`, { token: S, headers: { 'Idempotency-Key': key('rt2-x') } });
    rec('export', 'fulfil by staff without admin:customers:write → 403', f1.status === 403, ev(f1));
    const f1b = await req('POST', `/api/admin/v1/data-export-requests/${xid}/fulfil`, { token: C, headers: { 'Idempotency-Key': key('rt2-x') } });
    rec('export', 'fulfil by customer → 403', f1b.status === 403, ev(f1b));
    const a0 = audit();
    await stepUp(A, ACC.admin[1]);
    const f2 = await req('POST', `/api/admin/v1/data-export-requests/${xid}/fulfil`, { token: A, headers: { 'Idempotency-Key': key('rt2-x') } });
    rec('export', 'fulfil by admin + step-up → 200, 1 audit row', f2.status === 200 && audit() === a0 + 1, `${ev(f2)} audit ${a0}→${audit()}`);
    const r1 = await rawGet(`/api/data-export/file/${xid}`, C);
    const loc = r1.headers.get('location') ?? '';
    rec('export', 'owner GET /api/data-export/file/{id} (Bearer) → 302 signed URL, no-store', r1.status === 302 && /expires=\d+&sig=[0-9a-f]{64}/.test(loc) && /no-store/.test(r1.headers.get('cache-control') ?? ''), `HTTP ${r1.status} loc=${loc.slice(0, 120)}`);
    const u = new URL(loc, ORIGIN); const signedPath = u.pathname + u.search;
    const r2 = await rawGet(signedPath, C);
    const body = await r2.text();
    rec('export', 'follow → 200 JSON attachment, no-store, nosniff', r2.status === 200 && /application\/json/.test(r2.headers.get('content-type') ?? '') && /^attachment/.test(r2.headers.get('content-disposition') ?? '') && /no-store/.test(r2.headers.get('cache-control') ?? ''),
      `HTTP ${r2.status} ct=${r2.headers.get('content-type')} cd=${r2.headers.get('content-disposition')} cc=${r2.headers.get('cache-control')}`);
    let j = null; try { j = JSON.parse(body); } catch { /* not json */ }
    const keysDeep = []; const walk = (o, p = '') => { if (o && typeof o === 'object') for (const [k, v] of Object.entries(o)) { keysDeep.push(`${p}${k}`); walk(v, `${p}${k}.`); } }; walk(j);
    const secretKeys = keysDeep.filter((k) => /(password|pass_hash|passwordhash|token|otp|code_hash|secret|pepper|mfa|totp|refresh)/i.test(k.split('.').pop()));
    rec('export', 'file has no secret keys (password/token/otp/secret)', !!j && secretKeys.length === 0, `top=${Object.keys(j ?? {}).join(',')} secret=${secretKeys.slice(0, 8).join(',')}`);
    const others = sql(`select string_agg(email, ',') from users where id <> ${custId} and email is not null`).split(',').filter(Boolean);
    const leakedEmails = others.filter((e) => body.includes(e));
    const otherBank = sql(`select string_agg(bank_account_number, ',') from taskers where bank_account_number is not null and bank_account_number <> ''`).split(',').filter((x) => x && x.length >= 6);
    const leakedBank = otherBank.filter((b) => body.includes(b));
    const uidVals = []; const walkU = (o) => { if (o && typeof o === 'object') for (const [k, v] of Object.entries(o)) { if (/^(userId|user_id|customerId|customer_id)$/.test(k) && v != null) uidVals.push(Number(v)); walkU(v); } }; walkU(j);
    rec('export', 'only the owner\'s rows (no other user email / userId / tasker bank account)', leakedEmails.length === 0 && leakedBank.length === 0 && uidVals.every((v) => v === custId),
      `emails=${leakedEmails.slice(0, 3)} bank=${leakedBank.length} userIds=${[...new Set(uidVals)].join(',')} size=${body.length}`);
    const other = await rawGet(signedPath, P2);
    rec('export', 'another user with the owner\'s signed URL → 404', other.status === 404, `HTTP ${other.status}`);
    const otherMint = await rawGet(`/api/data-export/file/${xid}`, P2);
    rec('export', 'another user mint → 404', otherMint.status === 404, `HTTP ${otherMint.status}`);
    const sigT = signedPath.replace(/sig=([0-9a-f])/, (m, c) => `sig=${c === 'a' ? 'b' : 'a'}`);
    const t1 = await rawGet(sigT, C);
    rec('export', 'tampered sig → 404', t1.status === 404, `HTTP ${t1.status}`);
    const t2 = await rawGet(signedPath.replace(`/file/${xid}?`, `/file/${xid + 1}?`), C);
    rec('export', 'tampered id → 404', t2.status === 404, `HTTP ${t2.status}`);
    const sec = envLocal.URL_SIGNING_SECRET || '';
    const past = Math.floor(Date.now() / 1000) - 60;
    const sigPast = crypto.createHmac('sha256', sec).update(`api/data-export/file/${xid}|${past}`).digest('hex');
    const t3 = await rawGet(`/api/data-export/file/${xid}?expires=${past}&sig=${sigPast}`, C);
    rec('export', 'expired (correctly signed, past expiry) → 404', sec.length >= 32 && t3.status === 404, `HTTP ${t3.status}`);
    const anon = await rawGet(signedPath, null);
    rec('export', 'no auth (signed URL only) → 404', anon.status === 404, `HTTP ${anon.status}`);
  }

  // ── MQA-56 / MQA-57: unknown /api/* (outside v1) → JSON 404 envelope for a signed-in web user; /api/reviews no 307 ──
  if (on('mqa56')) {
    const ck = await webLogin(...ACC.customer);
    rec('mqa56', 'customer web cookie session', !!ck, '');
    for (const p of ['/api/no-such-route', '/api/bookings/zzz/nothing', '/api/search', '/api/neighborhoods']) {
      for (const [m, hdr] of [['GET', {}], ['POST', { 'Content-Type': 'application/json', Origin: ORIGIN }]]) {
        await sleep(PACE);
        const r = await fetch(ORIGIN + p, { method: m, headers: { Cookie: ck, Accept: 'text/html,application/json', ...hdr }, body: m === 'POST' ? '{}' : undefined, redirect: 'manual' });
        const t = await r.text(); let jj = null; try { jj = JSON.parse(t); } catch { /* html */ }
        rec('mqa56', `web cookie ${m} ${p} → 404 JSON envelope`, r.status === 404 && jj?.ok === false && jj?.code === 'NOT_FOUND' && !!r.headers.get('x-trace-id'), `HTTP ${r.status} ${jj ? JSON.stringify(jj).slice(0, 100) : 'non-JSON ' + t.slice(0, 40).replace(/\s+/g, ' ')}`);
      }
    }
    {
      // customer cookie in the legacy cookie-gated /api/admin/* namespace → 403 envelope (middleware admin gate), never HTML
      await sleep(PACE);
      const r = await fetch(ORIGIN + '/api/admin/no-such', { headers: { Cookie: ck, Accept: 'application/json' }, redirect: 'manual' });
      const t = await r.text();
      rec('mqa56', 'customer cookie GET /api/admin/no-such → 403/404 envelope', [403, 404].includes(r.status) && /"ok":false/.test(t), `HTTP ${r.status} ${t.slice(0, 80)}`);
    }
    // MQA-57: no page redirect on /api/reviews. Signed-in web user → catch-all 404 envelope; a request without
    // a cookie session is stopped earlier by the middleware cookie gate (401 envelope) — either way never 307.
    for (const [who, h, want] of [['web cookie', { Cookie: ck }, [404]], ['anonymous', {}, [401, 404]], ['Bearer', { Authorization: `Bearer ${C}` }, [401, 404]]]) {
      await sleep(PACE);
      const r = await fetch(ORIGIN + '/api/reviews', { headers: { Accept: 'application/json', ...h }, redirect: 'manual' });
      const t = await r.text();
      rec('mqa57', `${who} GET /api/reviews → no redirect, ${want.join('/')} envelope`, !r.headers.get('location') && want.includes(r.status) && /"ok":false/.test(t), `HTTP ${r.status} loc=${r.headers.get('location')} ${t.slice(0, 80)}`);
    }
    for (const p of ['/vi/reviews', '/en/reviews/x']) {
      await sleep(PACE);
      const r = await fetch(ORIGIN + p, { redirect: 'manual' });
      rec('mqa57', `GET ${p} still redirects to bookings`, [307, 308].includes(r.status) && /\/bookings$/.test(r.headers.get('location') ?? ''), `HTTP ${r.status} ${r.headers.get('location')}`);
    }
  }

  const fail = results.filter((r) => r.ok === false).length;
  console.log(`\n${results.filter((r) => r.ok).length} pass, ${fail} fail, ${results.filter((r) => r.ok === null).length} info`);
  process.exit(fail ? 1 : 0);
}
main().catch((e) => { console.error(e); process.exit(1); });
