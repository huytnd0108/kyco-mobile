#!/usr/bin/env node
// Mobile-QA RE-TEST of the MQA rows marked FIXED on feat/web-api-only (lab only).
//   API_BASE=http://127.0.0.1:4142/api/v1 node tool/api-contract/retest.mjs [--only=setup,mqa24,mqa23,mqa20,mqa8,mqa10,mqa33,adminops,adminsmoke]
// Creates its own temp users (mqa-rt-*@qa.local) + bookings in kyco_wapi_mobileqa. Never kyco.vn.
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';

const BASE = process.env.API_BASE || 'http://127.0.0.1:4142/api/v1';
const ROOT = BASE.replace(/\/api\/v1$/, '');
if (/kyco\.vn/.test(BASE)) { console.error('refusing kyco.vn'); process.exit(2); }
const DB = 'kyco_wapi_mobileqa';
const WT = '/home/bi/w/AppDroid1-ori/kyco-wt/mobile-qa';
const PW = 'RetestQa12345!';
const only = (process.argv.find((a) => a.startsWith('--only=')) || '').slice(7).split(',').filter(Boolean);
const want = (g) => only.length === 0 || only.includes(g);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const PACE = Number(process.env.PACE_MS ?? 700);

const results = [];
function record(g, name, ok, detail = '') { results.push({ g, name, ok }); console.log(`${ok ? 'PASS' : 'FAIL'}  [${g}] ${name}${detail ? '  — ' + detail : ''}`); }
function info(g, name, detail) { console.log(`INFO  [${g}] ${name}  — ${detail}`); }

async function raw(method, url, { token, body, form, headers = {} } = {}) {
  if (PACE) await sleep(PACE);
  const h = { Accept: 'application/json', 'User-Agent': 'kyco-mobile-retest/1', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  let b;
  if (form) b = form; else if (body !== undefined) { h['Content-Type'] = 'application/json'; b = JSON.stringify(body); }
  const res = await fetch(url, { method, headers: h, body: b });
  const text = await res.text();
  let json = null; try { json = text ? JSON.parse(text) : null; } catch { /* */ }
  return { status: res.status, json, text };
}
const call = (m, p, o) => raw(m, BASE + p, o);
const acall = (m, p, o) => raw(m, ROOT + '/api/admin/v1' + p, o);
const data = (r) => (r.json && typeof r.json === 'object' && 'data' in r.json ? r.json.data : r.json);
const short = (r) => `HTTP ${r.status} ${(r.text || '').replace(/"traceId":"[^"]+",?/, '').slice(0, 200)}`;
const envErr = (r) => r.json && r.json.ok === false && typeof r.json.code === 'string';
async function expect(g, name, r, statuses, check) {
  const ok0 = [].concat(statuses).includes(r.status);
  let why = ok0 ? null : `expected ${JSON.stringify(statuses)}`;
  if (!why && r.status >= 400 && !envErr(r)) why = 'non-envelope error';
  if (!why && check) { const c = check(data(r), r); if (c !== true) why = `check: ${c}`; }
  record(g, name, !why, `${why ? why + '; ' : ''}${short(r).slice(0, 180)}`);
  return r;
}

function sql(q) {
  return execFileSync('docker', ['exec', '-e', 'PGOPTIONS=-csearch_path=kycore,public', 'appdroid-pg',
    'psql', '-U', 'postgres', '-d', DB, '-v', 'ON_ERROR_STOP=1', '-tAc', q], { encoding: 'utf8' }).trim();
}
const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;
const hash = () => createRequire(`${WT}/package.json`)('bcryptjs').hashSync(PW, 10);
function ensureUser(email, role, phone) {
  const h = hash();
  sql(`insert into users (email,password_hash,name,role,is_active,token_version,phone,phone_verified_at)
       select ${lit(email)},${lit(h)},${lit('Retest ' + email.split('@')[0])},${lit(role)},true,0,${phone ? lit(phone) : 'null'},${phone ? 'now()' : 'null'}
       where not exists (select 1 from users where email=${lit(email)})`);
  sql(`update users set is_active=true, token_version=0, password_hash=${lit(h)}, role=${lit(role)} where email=${lit(email)}`);
  return Number(sql(`select id from users where email=${lit(email)}`));
}
const TOKCACHE = process.env.RETEST_TOKEN_CACHE || '/tmp/claude-1000/-home-bi-w-AppDroid1-ori/e83cad69-666e-4383-b5b7-0d5045b1a7d0/scratchpad/retest-tokens.json';
async function login(email, password) {
  const fs = await import('node:fs');
  let cache = {}; try { cache = JSON.parse(fs.readFileSync(TOKCACHE, 'utf8')); } catch { /* */ }
  const c = cache[email];
  if (c && Date.now() - c.at < 8 * 60_000) {
    const me = await call('GET', '/me', { token: c.token });
    if (me.status === 200) { info('auth', `login ${email}`, 'cached token'); return c.token; }
  }
  for (let i = 0; i < 6; i++) {
    const r = await call('POST', '/auth/login', { body: { email, password } });
    if (r.status === 429) { const ra = Number(r.json?.retryAfter || 0) || 15; console.log(`  login 429, waiting ${ra}s`); await sleep(ra * 1000 + 500); continue; }
    record('auth', `login ${email}`, r.status === 200, short(r).slice(0, 60));
    const t = data(r)?.accessToken;
    if (t) { cache[email] = { token: t, at: Date.now() }; fs.writeFileSync(TOKCACHE, JSON.stringify(cache)); }
    return t;
  }
  record('auth', `login ${email}`, false, 'rate limited'); return null;
}
const RUN_DATE = new Date(Date.now() + 7 * 3600_000 + (30 + Math.floor(Math.random() * 30)) * 86_400_000).toISOString().slice(0, 10);
const bookingBody = (serviceId, hhmm, extra = {}) => ({
  serviceId, scheduledAt: `${RUN_DATE}T${hhmm}:00`, district: 'Quận 1', ward: 'Bến Nghé',
  addressLine: '12 Lê Lợi', notes: 'retest-qa', paymentMethod: 'cash', idempotencyKey: randomUUID(), ...extra,
});
async function mkBooking(C, serviceId, hhmm, extra) {
  const r = await call('POST', '/bookings', { token: C, body: bookingBody(serviceId, hhmm, extra) });
  const id = data(r)?.bookingId;
  record('setup', `create booking ${hhmm} → ${id}`, r.status === 201 && id > 0, short(r).slice(0, 120));
  return id;
}
const jobOf = (bid) => Number(sql(`select id from jobs where booking_id=${bid} order by id limit 1`) || 0);

// tiny valid PNG (1x1)
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
const pngFile = (n) => new File([PNG], n, { type: 'image/png' });
// MQA-58 (8c98156/8877d67): KYC files are typed by their bytes and must be ≥10 KB, so the 1×1 PNG is
// `too-small` on every KYC door — a successful KYC submit needs a real image (RT2_FIXTURES/real.jpg).
const JPEG_REAL = (() => { try { return fs.readFileSync(`${process.env.RT2_FIXTURES || '/tmp/claude-1000/-home-bi-w-AppDroid1-ori/e83cad69-666e-4383-b5b7-0d5045b1a7d0/scratchpad/fx'}/real.jpg`); } catch { return null; } })();
const jpegFile = (n) => new File([JPEG_REAL ?? PNG], n, { type: 'image/jpeg' });

async function main() {
  console.log(`retest against ${BASE} run date ${RUN_DATE}`);
  const t2User = ensureUser('mqa-rt-tasker2@qa.local', 'tasker', null);
  sql(`insert into taskers (name,email,user_account_id,is_verified) select 'Retest Tasker2','mqa-rt-tasker2@qa.local',${t2User},true
       where not exists (select 1 from taskers where user_account_id=${t2User})`);
  const t2 = Number(sql(`select id from taskers where user_account_id=${t2User}`));
  const upUser = ensureUser('mqa-rt-upgrade@qa.local', 'customer', '+84901119901');
  info('setup', 'temp users', `tasker2 user=${t2User} taskers.id=${t2}; upgrade customer user=${upUser}`);

  const C = await login('demo@demo.local', 'demo12345');
  const P = await login('tasker@qa.local', 'TaskerQa12345!');
  const P2 = await login('mqa-rt-tasker2@qa.local', PW);
  const A = await login('admin@qa.local', 'Admin12345qa');
  const U = await login('mqa-rt-upgrade@qa.local', PW);
  const sv = data(await call('GET', '/services?page=1&limit=100')) || [];
  const svList = (Array.isArray(sv) ? sv : sv.items || []).slice().sort((a, b) => (a.durationMinutes || 999) - (b.durationMinutes || 999));
  const serviceId = svList[0]?.id;
  info('setup', 'service', `${serviceId} (${svList[0]?.durationMinutes} min)`);

  // ── MQA-24 geocode at create + unverified check-in ────────────────────
  let jobA = 0, bookingA = 0;
  if (want('mqa24') || want('mqa23') || want('mqa20')) {
    const g = 'mqa24';
    bookingA = await mkBooking(C, serviceId, '09:00');
    const t0 = Date.now(); let coords = '';
    for (let i = 0; i < 8; i++) { await sleep(500); coords = sql(`select coalesce(address_lat::text,'null')||','||coalesce(address_lng::text,'null') from bookings where id=${bookingA}`); if (!coords.startsWith('null')) break; }
    info(g, `booking ${bookingA} coords after ${Date.now() - t0}ms`, coords);
    record(g, 'booking geocoded within ~4s of create', !coords.startsWith('null'), coords);
    // force NULL coords → unverified check-in path
    sql(`update bookings set address_lat=null, address_lng=null where id=${bookingA}`);
    jobA = jobOf(bookingA);
    // FE-06 (user decision 2026-10-10): check-in only from scheduledAt − 30 min to + 2 h → move into the window
    sql(`update bookings set scheduled_at=now() + interval '10 minutes' where id=${bookingA}`);
    const cl = await call('POST', `/tasker/jobs/${jobA}/claim`, { token: P });
    if (cl.status !== 200) { info(g, 'claim failed, assigning in DB', short(cl)); sql(`update jobs set tasker_id=1, status='active' where id=${jobA}`); }
    const evBefore = Number(sql(`select count(*) from events where kind='checkin_geofence_unverified'`));
    const ci = await call('POST', `/tasker/jobs/${jobA}/check-in`, { token: P, body: { lat: 10.7769, lon: 106.7009, accuracyM: 12 } });
    await expect(g, `check-in job ${jobA} with NULL booking coords → allowed`, ci, [200, 201]);
    await sleep(800);
    const wg = sql(`select coalesce(within_geofence::text,'NULL') from tasker_check_ins where job_id=${jobA} and event_kind='arrival'`);
    record(g, 'tasker_check_ins.within_geofence IS NULL', wg === 'NULL', `within_geofence=${wg}`);
    const ev = sql(`select id||'|'||coalesce(user_id::text,'null')||'|'||payload_json::text from events where kind='checkin_geofence_unverified' order by id desc limit 1`);
    const evAfter = Number(sql(`select count(*) from events where kind='checkin_geofence_unverified'`));
    record(g, 'event checkin_geofence_unverified written', evAfter === evBefore + 1 && ev.includes(`"jobId": ${jobA}`), ev);
    const evUid = ev.split('|')[1];
    record(g, 'event user_id is the tasker USER (3), not taskers.id', evUid === '3', `events.user_id=${evUid} (taskers.id=1, tasker user=3, user 1 = demo customer)`);
    // 2nd tasker (taskers.id has no matching users.id) — is the audit event persisted at all?
    const bookingT2 = await mkBooking(C, serviceId, '13:00');
    await sleep(3000);
    sql(`update bookings set address_lat=null, address_lng=null, scheduled_at=now() + interval '10 minutes' where id=${bookingT2}`);
    const jobT2 = jobOf(bookingT2);
    sql(`update jobs set tasker_id=${t2}, status='active' where id=${jobT2}`);
    const ev2b = Number(sql(`select count(*) from events where kind='checkin_geofence_unverified'`));
    const ci2 = await call('POST', `/tasker/jobs/${jobT2}/check-in`, { token: P2, body: { lat: 10.7769, lon: 106.7009, accuracyM: 12 } });
    await expect(g, `tasker2 check-in job ${jobT2} NULL coords → allowed`, ci2, [200, 201]);
    await sleep(800);
    const ev2a = Number(sql(`select count(*) from events where kind='checkin_geofence_unverified'`));
    record(g, `tasker2 (taskers.id=${t2}) unverified event persisted`, ev2a === ev2b + 1, `events ${ev2b} → ${ev2a}`);
    sql(`update jobs set status='closed' where id=${jobT2}`);
  }

  // ── MQA-23 IDOR: tasker2 on tasker1's job ─────────────────────────────
  if (want('mqa23') && jobA) {
    const g = 'mqa23';
    const snap = () => sql(`select status||'|'||coalesce(tasker_id::text,'')||'|'||coalesce(started_at::text,'')||'|'||coalesce(finished_at::text,'')||'|'||coalesce(before_photos::text,'-')||coalesce(after_photos::text,'-') from jobs where id=${jobA}`)
      + '|' + sql(`select status from bookings where id=${bookingA}`)
      + '|' + sql(`select count(*) from messages where booking_id=${bookingA}`)
      + '|' + sql(`select count(*) from disputes where booking_id=${bookingA}`)
      + '|' + sql(`select count(*) from tasker_check_ins where job_id=${jobA}`)
      + '|' + sql(`select count(*) from location_sessions where job_id=${jobA}`);
    const s0 = snap();
    await expect(g, `tasker2 GET /tasker/jobs/${jobA} → 404`, await call('GET', `/tasker/jobs/${jobA}`, { token: P2 }), 404);
    const doors = [
      ['confirm', undefined], ['message', { body: 'idor' }], ['start-tracking', undefined],
      ['check-in', { lat: 10.7769, lon: 106.7009, accuracyM: 10 }], ['check-out', { lat: 10.7769, lng: 106.7009, accuracyM: 10 }],
      ['complete', undefined], ['photos', { slot: 'before', mediaIds: [1] }],
      ['decline', { reason: 'idor' }], ['complaint', { category: 'other', description: 'idor test by tasker2' }],
    ];
    for (const [door, body] of doors) {
      await expect(g, `tasker2 POST ${door} on job ${jobA} → 404`, await call('POST', `/tasker/jobs/${jobA}/${door}`, { token: P2, body }), 404);
    }
    const s1 = snap();
    record(g, 'job/booking/messages/disputes/check-ins/sessions unchanged', s0 === s1, `${s0} → ${s1}`);
  }

  // ── MQA-20 photos with unknown / foreign media ids ────────────────────
  if (want('mqa20') && jobA) {
    const g = 'mqa20';
    const before = sql(`select before_photos::text from jobs where id=${jobA}`);
    await expect(g, 'unknown mediaIds → 404/422', await call('POST', `/tasker/jobs/${jobA}/photos`, { token: P, body: { slot: 'before', mediaIds: [99999999] } }), [404, 422]);
    // foreign: a READY checkin asset for THIS booking but owned by the customer
    const fid = Number(sql(`insert into media_assets (category,entity_type,entity_id,owner_user_id,object_path,mime_type,size_bytes,status,finalized_at)
      values ('checkin','booking',${bookingA},1,'retest/foreign-${bookingA}-${Date.now()}.jpg','image/jpeg',100,'ready',now()) returning id`).split('\n')[0]);
    await expect(g, `foreign mediaId ${fid} (customer-owned) → 404/422`, await call('POST', `/tasker/jobs/${jobA}/photos`, { token: P, body: { slot: 'before', mediaIds: [fid] } }), [404, 422]);
    const mixed = Number(sql(`insert into media_assets (category,entity_type,entity_id,owner_user_id,object_path,mime_type,size_bytes,status,finalized_at)
      values ('checkin','booking',${bookingA},3,'retest/own-${bookingA}-${Date.now()}.jpg','image/jpeg',100,'ready',now()) returning id`).split('\n')[0]);
    await expect(g, `own ${mixed} + unknown → 422 (all-or-nothing)`, await call('POST', `/tasker/jobs/${jobA}/photos`, { token: P, body: { slot: 'before', mediaIds: [mixed, 99999998] } }), [404, 422]);
    const after = sql(`select before_photos::text from jobs where id=${jobA}`);
    record(g, 'before_photos unchanged after rejected batches', before === after, `${before} → ${after}`);
    await expect(g, `own ready mediaId ${mixed} → 200 stored 1`, await call('POST', `/tasker/jobs/${jobA}/photos`, { token: P, body: { slot: 'before', mediaIds: [mixed] } }), [200, 201], (d) => d?.stored === 1 || JSON.stringify(d));
    const legacy = await call('POST', `/tasker/jobs/${jobA}/photos`, { token: P, body: { slot: 'mid', urls: ['https://evil.example/not-ours.jpg'] } });
    info(g, 'legacy urls[] arbitrary https host', `${short(legacy).slice(0, 120)}; mid_photos=${sql(`select mid_photos::text from jobs where id=${jobA}`)}`);
  }

  // ── MQA-8 dispute fields on job detail ────────────────────────────────
  if (want('mqa8')) {
    const g = 'mqa8';
    const b = await mkBooking(C, serviceId, '15:00');
    await sleep(500);
    const j = jobOf(b);
    sql(`update jobs set tasker_id=1, status='active', finished_at=now() where id=${j}`);
    sql(`update bookings set status='AWAITING_CUSTOMER_CONFIRMATION', completed_at=now(), customer_disputed_at=now(),
         customer_dispute_note='RETEST chưa lau kính', tasker_resubmitted_at=null where id=${b}`);
    await expect(g, `owner GET /tasker/jobs/${j} exposes dispute fields`, await call('GET', `/tasker/jobs/${j}`, { token: P }), 200, (d) => {
      const bk = d?.booking || {};
      if (!('customerDisputedAt' in bk) || !('taskerResubmittedAt' in bk) || !('customerDisputeNote' in bk)) return 'missing keys ' + Object.keys(bk).join(',');
      return (bk.customerDisputedAt && bk.customerDisputeNote === 'RETEST chưa lau kính' && bk.taskerResubmittedAt === null) || JSON.stringify(bk);
    });
    sql(`update bookings set tasker_resubmitted_at=now() where id=${b}`);
    await expect(g, 'owner sees taskerResubmittedAt once set', await call('GET', `/tasker/jobs/${j}`, { token: P }), 200, (d) => !!d?.booking?.taskerResubmittedAt || JSON.stringify(d?.booking));
    const nr = await expect(g, 'non-owner tasker2 → 404', await call('GET', `/tasker/jobs/${j}`, { token: P2 }), 404);
    record(g, 'non-owner body never contains dispute note/keys', !/RETEST chưa|customerDispute|taskerResubmitted/.test(nr.text), nr.text.slice(0, 120));
    await expect(g, 'customer token → 401/403', await call('GET', `/tasker/jobs/${j}`, { token: C }), [401, 403]);
    sql(`update jobs set status='closed' where id=${j}`);
  }

  // ── MQA-33 contract consistency ───────────────────────────────────────
  if (want('mqa33')) {
    const g = 'mqa33';
    const me0 = sql(`select name||'|'||coalesce(province_code::text,'') from users where id=1`);
    await expect(g, 'PATCH /me {province:79} (unknown key) → 422', await call('PATCH', '/me', { token: C, body: { province: 79 } }), 422, (d, r) => JSON.stringify(r.json).includes('province') || 'fields lacks province');
    await expect(g, 'PATCH /me {bogusKey} → 422', await call('PATCH', '/me', { token: C, body: { bogusKey: 'x' } }), 422);
    const me1 = sql(`select name||'|'||coalesce(province_code::text,'') from users where id=1`);
    record(g, 'users row unchanged', me0 === me1, `${me0} → ${me1}`);
    await expect(g, 'POST /bookings unknown serviceId → 422 fields.serviceId', await call('POST', '/bookings', { token: C, body: bookingBody(999999, '10:00') }), 422,
      (d, r) => (r.json?.fields && 'serviceId' in r.json.fields && !('service_id' in r.json.fields)) || JSON.stringify(r.json?.fields ?? r.json));
  }

  // ── MQA-10 become-tasker upgrade (signup limiter 3/60s → 21s pace) ────
  if (want('mqa10')) {
    const g = 'mqa10';
    const form = (files = ['cccd_front', 'cccd_back', 'selfie']) => {
      const f = new FormData(); f.set('name', 'Retest Upgrade'); f.set('city', 'Hồ Chí Minh'); f.set('district', 'Quận 1');
      for (const k of files) f.set(k, jpegFile(`${k}.jpg`));
      return f;
    };
    const up = (tok, f) => call('POST', '/become-tasker/upgrade', { token: tok, form: f });
    const kyc0 = sql(`select count(*) from kyc_documents where user_id=${upUser}`);
    await expect(g, 'missing ALL files → 422', await up(U, form([])), 422); await sleep(21000);
    const r1 = await up(U, form(['cccd_front', 'cccd_back']));
    await expect(g, 'missing selfie → 422', r1, 422); await sleep(21000);
    const r2 = await up(U, form());
    await expect(g, 'full upgrade → 201 (or 503 storage unconfigured, never 500)', r2, [201, 503]);
    const role = sql(`select role from users where id=${upUser}`);
    info(g, 'after full upgrade', `role=${role}; kyc_documents ${kyc0} → ${sql(`select count(*) from kyc_documents where user_id=${upUser}`)}`);
    await sleep(21000);
    if (role !== 'pending_tasker') { sql(`update users set role='pending_tasker' where id=${upUser}`); info(g, 'forced role pending_tasker in DB to test idempotent retry', ''); }
    await expect(g, 'retry when pending_tasker → 200 alreadyPending', await up(U, form()), 200, (d) => d?.alreadyPending === true || JSON.stringify(d));
    await sleep(21000);
    await expect(g, 'tasker token → 403/409', await up(P, form()), [403, 409]);
    await expect(g, 'admin token → 403/409', await up(A, form()), [403, 409]);
    await expect(g, 'no token → 401', await up(null, form()), 401);
  }

  // ── admin-ops MQA-27..31 ──────────────────────────────────────────────
  if (want('adminops')) {
    const g = 'adminops';
    await expect(g, 'admin step-up (password)', await call('POST', '/auth/step-up', { token: A, body: { method: 'password', password: 'Admin12345qa' } }), 200);
    const route = '/services';
    const seoRows = () => sql(`select string_agg(key||'='||value::text, ' ; ' order by key) from site_settings where key like 'seo:${route}:%'`);
    const orig = seoRows();
    await expect(g, 'seo full PUT', await acall('PUT', '/seo', { token: A, body: { route, title: 'RT title', description: 'RT desc', ogImage: 'https://cdn.example.com/og.png' } }), 200);
    await expect(g, 'seo partial PUT {title}', await acall('PUT', '/seo', { token: A, body: { route, title: 'RT title 2' } }), 200);
    const after = seoRows();
    record('mqa27', 'description + ogImage kept after partial PUT (DB)', after.includes('RT desc') && after.includes('og.png') && after.includes('RT title 2'), after);
    for (const [label, body] of [
      ['5000-char title', { title: 'x'.repeat(5000) }], ['1001-char description', { description: 'd'.repeat(1001) }],
      ['ogImage javascript:', { ogImage: 'javascript:alert(1)' }], ['ogImage data:', { ogImage: 'data:image/png;base64,AAAA' }],
      ['ogImage http:', { ogImage: 'http://cdn.example.com/x.png' }], ['ogImage //host', { ogImage: '//evil.example/x.png' }],
    ]) await expect('mqa28', `seo ${label} → 422`, await acall('PUT', '/seo', { token: A, body: { route, ...body } }), 422);
    await expect('mqa28', 'seo ogImage relative /og.png → 200', await acall('PUT', '/seo', { token: A, body: { route, ogImage: '/og.png' } }), 200);
    record('mqa28', 'DB not polluted by rejected values', !/javascript:|data:image|xxxxxxxxxx|http:\/\/cdn/.test(seoRows()), seoRows());
    // restore: clear the three fields if there was no override before
    if (!orig) sql(`delete from site_settings where key like 'seo:${route}:%'`);
    info(g, 'seo restored', `orig=${orig || '(none)'} now=${seoRows() || '(none)'}`);

    const f = new FormData(); f.set('file', pngFile('x.png'));
    const sid = Number(sql(`select min(id) from services`));
    const img0 = sql(`select coalesce(image_url,'') from services where id=${sid}`);
    // Lab storage is now the fake GCS (lab-fakegcs.sh): configured → 201 (image_url restored after);
    // without it → 503 STORAGE_UNAVAILABLE. Never 500.
    const gcsOn = !!process.env.GCS_API_ENDPOINT;
    const ir = await acall('POST', `/catalog/services/${sid}/image`, { token: A, form: f });
    await expect('mqa29', `catalog service ${sid} image, storage ${gcsOn ? 'configured → 201' : 'unconfigured → 503'}`, ir, gcsOn ? [201] : [503]);
    if (ir.status === 201) { sql(`update services set image_url=${img0 ? `'${img0.replace(/'/g, "''")}'` : 'null'} where id=${sid}`); info('mqa29', 'image_url restored', img0); }
    else record('mqa29', 'service image_url unchanged', sql(`select coalesce(image_url,'') from services where id=${sid}`) === img0, img0);
    await expect('mqa30', 'PUT /flags/not_a_flag → 404', await acall('PUT', '/flags/not_a_flag', { token: A, body: { value: true } }), 404);
    const wh = await expect('mqa31', 'POST /webhooks returns id', await acall('POST', '/webhooks', { token: A, body: { url: 'https://example.com/kyco-retest-hook', events: ['booking.created'] } }), 201, (d) => (Number(d?.id) > 0) || JSON.stringify(d));
    const whId = data(wh)?.id;
    if (whId) {
      await sleep(500);
      const au = sql(`select coalesce(target_id::text,'NULL') from admin_audit where action='admin.webhook.create' order by id desc limit 1`);
      record('mqa31', 'admin_audit target_id = webhook id', au === String(whId), `target_id=${au} id=${whId}`);
      await expect('mqa31', `DELETE /webhooks/${whId} (cleanup)`, await acall('DELETE', `/webhooks/${whId}`, { token: A }), [200, 204]);
      record('mqa31', 'webhook row gone', sql(`select count(*) from webhooks where id=${whId}`) === '0');
    }
  }

  // ── admin smoke (Decision 15 explicit scopes) ─────────────────────────
  if (want('adminsmoke')) {
    const g = 'adminsmoke';
    const paths = ['/dashboard', '/taskers', '/customers', '/jobs/pool', '/payments/dashboard', '/payments/transactions', '/disputes', '/fines',
      '/flags/restore-defaults', '/catalog/services', '/catalog/categories', '/content', '/audit', '/audit-log', '/staff', '/subscriptions', '/coverage',
      '/webhooks', '/cities', '/finance/overview', '/sos/overview', '/fraud/overview', '/cron-health', '/notification-health', '/tasker-debt',
      '/insurance-fund', '/damage-claims', '/incentives', '/referral-programs', '/availability', '/buildings', '/b2b', '/commission/rules',
      '/payments/alerts', '/payments/webhook-logs', '/funnel', '/slot-alerts', '/trust-strip', '/site-content', '/settings/brand', '/maintenance', '/cash-districts'];
    for (const p of paths) {
      const r = await acall('GET', p, { token: A });
      const ok = r.status === 200 || r.status === 405; // 405 = route has no GET
      record(g, `admin GET ${p} → ${r.status}`, ok && r.status !== 403, r.status === 200 ? '' : short(r).slice(0, 160));
    }
    await expect(g, 'customer token on admin /dashboard → 403', await acall('GET', '/dashboard', { token: C }), [401, 403]);
  }

  const fails = results.filter((r) => !r.ok);
  console.log(`\n${results.length - fails.length}/${results.length} passed`);
  for (const f of fails) console.log(`  FAIL [${f.g}] ${f.name}`);
}
main().catch((e) => { console.error(e); process.exit(1); });
