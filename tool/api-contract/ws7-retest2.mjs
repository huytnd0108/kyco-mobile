// Mobile-QA RE-TEST round 2 (feat/web-api-only ≥ 1b2e0dc) — LAB ONLY (kyco_wapi_mobileqa).
//   API_ORIGIN=http://127.0.0.1:4142 node tool/api-contract/ws7-retest2.mjs [--only=role,sos,disputes,subs,tz,checkin,fund,booktz,vrf5]
// + MQA-51 trace header (--only=trace), MQA-52 error log by severity (errlog; needs SERVER_LOG=<next start log>),
//   MQA-53 seed guard / dispute reopen / cancellable pair (seed).
// Covers: MQA-46/VRF-4 role gate (photos/face-verify), MQA-44 SOS contract, disputes respond/resolve
// (bcfb263/12ea497), subscriptions durationHours (6cb73a9), MQA-45 weekly-availability conflict (1e37fc4),
// MQA-24/41 unverified check-in + events.user_id (478e453), MQA-40 fund floor (39cc604),
// booking scheduledAt with an hour-only offset, VRF-5 anonymous public-page burst (d8a9eff).
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

  const fail = results.filter((r) => r.ok === false).length;
  console.log(`\n${results.filter((r) => r.ok).length} pass, ${fail} fail, ${results.filter((r) => r.ok === null).length} info`);
  process.exit(fail ? 1 : 0);
}
main().catch((e) => { console.error(e); process.exit(1); });
