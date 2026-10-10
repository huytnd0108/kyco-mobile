#!/usr/bin/env node
// Mobile ↔ backend FLOW tests (companion to smoke.mjs). Where smoke.mjs checks
// each read endpoint once, this drives whole lifecycles with Bearer tokens:
//   A) auth regression — login, refresh rotation/reuse, logout revoke, step-up,
//      OTP request, banned user + revoked session (token_version bump)
//   B) tasker job lifecycle — customer CASH booking (exact mobile body) → pool
//      → claim → start-tracking → check-in (geofence) → media/photos → check-out
//      → complete → customer READS status; decline / message / complaint on other
//      jobs; availability weekly+date; goals PUT; support ticket; role + IDOR matrix
//   C) the kyco-api-issues-lessons checklist on every tasker write door
//      (partial PUT wipe, server validation, foreign/missing id → 404, envelope)
//
// Each mutation is sent twice where it matters: once with the body the Flutter
// client sends ("mobile:") and once with the body the route expects ("route:"),
// so a failure can be classified MOBILE (client shape) vs BACKEND (route/core).
//
//   API_BASE=http://127.0.0.1:4142/api/v1 node tool/api-contract/flows.mjs [--only=auth,lifecycle,decline,job3,availability,goals,support,matrix]
//
// QA-DB setup (temp users, booking geocode, assignment for the decline case,
// cleanup) runs through `docker exec appdroid-pg psql` against FLOWS_DB
// (default kyco_wapi_mobileqa). It refuses any other DB name unless
// FLOWS_ALLOW_DB=1. Money endpoints (cash-received, payouts, payments,
// confirm-completion) are NEVER called — the customer side only READS status.
// Requests are paced (FLOWS_PACE_MS, default 2100) because the edge limiter
// counts Bearer calls as anonymous 30/min/IP (MQA-1).
import { execFileSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';

const BASE = process.env.API_BASE || 'http://127.0.0.1:4142/api/v1';
if (/kyco\.vn/.test(BASE)) { console.error('refusing to run flows against kyco.vn'); process.exit(2); }
const DB = process.env.FLOWS_DB || 'kyco_wapi_mobileqa';
if (DB !== 'kyco_wapi_mobileqa' && !process.env.FLOWS_ALLOW_DB) { console.error(`refusing DB ${DB}`); process.exit(2); }
const PG_CONTAINER = process.env.FLOWS_PG_CONTAINER || 'appdroid-pg';
const WT = process.env.KYCO_WT || '/home/bi/w/AppDroid1-ori/kyco-wt/mobile-qa';

const ACC = {
  customer: [process.env.CUSTOMER_EMAIL || 'demo@demo.local', process.env.CUSTOMER_PASSWORD || 'demo12345'],
  tasker: [process.env.TASKER_EMAIL || 'tasker@qa.local', process.env.TASKER_PASSWORD || 'TaskerQa12345!'],
};
const TEMP_PW = 'FlowsQa12345!';
const TEMP = {
  ban: 'flows-ban@qa.local',
  revoke: 'flows-revoke@qa.local',
  tasker2: 'flows-tasker2@qa.local',
};
const TASKER2_ROW = Number(process.env.FLOWS_TASKER2_ID || 2);

const only = (process.argv.find((a) => a.startsWith('--only=')) || '').slice(7).split(',').filter(Boolean);
const want = (g) => only.length === 0 || only.includes(g);

// ── helpers (same shape as smoke.mjs) ───────────────────────────────────────
const results = [];
function record(group, name, ok, detail) {
  results.push({ group, name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  [${group}] ${name}${detail ? `  — ${detail}` : ''}`);
}
function info(group, name, detail) {
  results.push({ group, name, ok: true, info: true, detail });
  console.log(`INFO  [${group}] ${name}  — ${detail}`);
}
const PACE = Number(process.env.FLOWS_PACE_MS ?? 2100);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Login limiter is 5/min per IP: space /auth/login calls (FLOWS_LOGIN_GAP_MS, default 12.5 s).
const LOGIN_GAP = Number(process.env.FLOWS_LOGIN_GAP_MS ?? 12500);
let lastLogin = 0;
async function call(method, path, { token, body, headers = {} } = {}) {
  if (PACE) await sleep(PACE);
  if (path === '/auth/login' && LOGIN_GAP) {
    const wait = lastLogin + LOGIN_GAP - Date.now();
    if (wait > 0) await sleep(wait);
    lastLogin = Date.now();
  }
  const h = { Accept: 'application/json', 'User-Agent': 'kyco-mobile-flows/1', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  if (body !== undefined) h['Content-Type'] = 'application/json';
  const res = await fetch(BASE + path, { method, headers: h, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* non-JSON */ }
  return { status: res.status, json, text: text.slice(0, 300) };
}
const data = (r) => (r.json && typeof r.json === 'object' && 'data' in r.json ? r.json.data : r.json);
const short = (r) => `HTTP ${r.status} ${(r.text || '').replace(/"traceId":"[^"]+",?/, '').slice(0, 220)}`;
// Checklist #1: every error must be the API envelope {ok:false,code,message,retryable}.
const isEnvelopeErr = (r) => r.json && r.json.ok === false && typeof r.json.code === 'string' && typeof r.json.message === 'string';

async function expect(group, name, method, path, opts, statuses, check) {
  try {
    const r = await call(method, path, opts);
    const okStatus = (Array.isArray(statuses) ? statuses : [statuses]).includes(r.status);
    let why = okStatus ? null : 'expected ' + JSON.stringify(statuses);
    if (!why && r.status >= 400 && !isEnvelopeErr(r)) why = 'error not in API envelope';
    if (!why && check) { const c = check(data(r), r); if (c !== true) why = `shape: ${c}`; }
    record(group, `${method} ${path} ${name}`.trim(), !why, why ? `${why}; ${short(r)}` : short(r).slice(0, 140));
    return r;
  } catch (e) {
    record(group, `${method} ${path} ${name}`.trim(), false, String(e));
    return { status: 0, json: null };
  }
}

async function loginAs(email, password, group = 'auth', label = email) {
  const r = await call('POST', '/auth/login', { body: { email, password } });   // = kyco_api.dart login()
  const d = data(r);
  record(group, `login ${label}`, r.status === 200 && !!d?.accessToken, short(r).slice(0, 120));
  return r.status === 200 ? d : null;
}

// ── QA DB access (docker psql) ─────────────────────────────────────────────
function sql(q) {
  return execFileSync('docker', ['exec', '-e', 'PGOPTIONS=-csearch_path=kycore,public', PG_CONTAINER,
    'psql', '-U', 'postgres', '-d', DB, '-v', 'ON_ERROR_STOP=1', '-tAc', q], { encoding: 'utf8' }).trim();
}
const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;
function bcryptHash(pw) {
  const req = createRequire(`${WT}/package.json`);
  return req('bcryptjs').hashSync(pw, 10);
}
function ensureTempUser(email, role, phone = null) {
  const hash = bcryptHash(TEMP_PW);
  sql(`insert into users (email, password_hash, name, role, is_active, token_version${phone ? ', phone' : ''})
       select ${lit(email)}, ${lit(hash)}, ${lit('Flows QA ' + email.split('@')[0])}, ${lit(role)}, true, 0${phone ? ', ' + lit(phone) : ''}
       where not exists (select 1 from users where email=${lit(email)})`);
  sql(`update users set is_active=true, token_version=0, password_hash=${lit(hash)}, role=${lit(role)} where email=${lit(email)}`);
  return Number(sql(`select id from users where email=${lit(email)}`));
}

// VN-local 'YYYY-MM-DD' for a day offset, and the mobile scheduledAt wire format
// (booking.dart toCreateBody: '${scheduledDate}T${scheduledTime}:00').
function vnDate(offsetDays) {
  return new Date(Date.now() + 7 * 3600_000 + offsetDays * 86_400_000).toISOString().slice(0, 10);
}
const RUN_DAY = 3 + Math.floor(Math.random() * 20);
const RUN_DATE = vnDate(RUN_DAY);
// A Monday-anchored ISO weekday of RUN_DATE (0=Sun..6=Sat) for availability.
const RUN_DOW = new Date(RUN_DATE + 'T00:00:00Z').getUTCDay();

function mobileBookingBody(serviceId, hhmm, extra = {}) {
  return {
    serviceId,
    scheduledAt: `${RUN_DATE}T${hhmm}:00`,
    district: 'Quận 1',
    ward: 'Bến Nghé',
    addressLine: '12 Lê Lợi',
    notes: 'flows-qa',
    paymentMethod: 'cash',
    idempotencyKey: randomUUID(),
    ...extra,
  };
}

async function createBooking(C, serviceId, hhmm, label) {
  const body = mobileBookingBody(serviceId, hhmm);
  const r = await expect('booking', `mobile: create CASH booking (${label})`, 'POST', '/bookings', { token: C, body }, 201,
    (d) => (d?.kind === 'created' && d?.bookingId > 0 && d?.paymentMethod === 'cash') || JSON.stringify(d));
  return { bookingId: data(r)?.bookingId, body };
}

async function findPoolJob(P, bookingId, group) {
  const r = await call('GET', '/tasker/jobs/pool', { token: P });
  const d = data(r);
  const row = (d?.pool ?? []).find((x) => x.bookingId === bookingId);
  record(group, `GET /tasker/jobs/pool shows booking ${bookingId}`, !!row, row ? `jobId=${row.jobId} myRank=${row.myRank}` : short(r));
  if (row && 'dispatchCandidates' in row) record(group, 'pool row hides dispatchCandidates', false, 'leaked');
  return row?.jobId ?? Number(sql(`select id from jobs where booking_id=${Number(bookingId) || 0}`) || 0);
}

// ── main ─────────────────────────────────────────────────────────────────
async function main() {
  console.log(`flows against ${BASE} (db ${DB}, run date ${RUN_DATE})`);
  const health = await call('GET', '/services?page=1&limit=10');
  if (health.status === 503) { console.error('api_mobile_v1_enabled is OFF (503)'); process.exit(2); }
  const svcItems = data(health)?.items ?? data(health);
  let serviceId = Array.isArray(svcItems) && svcItems[0]?.id;
  if (!serviceId) {
    // QA seed: /services can be empty when no category row is active (MQA-5
    // cascade predicate). Fall back to an is_active service from the DB.
    serviceId = Number(sql(`select coalesce(min(id),0) from services where is_active`));
    info('booking', 'GET /services empty', `falling back to DB service ${serviceId}`);
  }
  if (!serviceId) { console.error('no active service'); process.exit(2); }

  // Temp users (QA DB only): two customers for ban/revoke, one second tasker.
  const banId = ensureTempUser(TEMP.ban, 'customer');
  const revokeId = ensureTempUser(TEMP.revoke, 'customer');
  const prov2UserId = ensureTempUser(TEMP.tasker2, 'tasker');
  sql(`update taskers set user_account_id=${prov2UserId} where id=${TASKER2_ROW} and (user_account_id is null or user_account_id=${prov2UserId})`);
  const prov2Linked = sql(`select user_account_id from taskers where id=${TASKER2_ROW}`) === String(prov2UserId);
  console.log(`temp users: ban=${banId} revoke=${revokeId} tasker2=${prov2UserId} (taskers.id=${TASKER2_ROW} linked=${prov2Linked})`);

  const cust = await loginAs(...ACC.customer, 'auth', 'customer');
  const prov = await loginAs(...ACC.tasker, 'auth', 'tasker');
  const prov2 = prov2Linked ? await loginAs(TEMP.tasker2, TEMP_PW, 'auth', 'tasker2 (temp)') : null;
  const C = cust?.accessToken, P = prov?.accessToken, P2 = prov2?.accessToken;
  if (!C || !P) { console.error('base logins failed'); process.exit(1); }

  // ── A) auth regression ────────────────────────────────────────────────
  if (want('auth')) {
    const g = 'auth';
    await expect(g, 'wrong password → 401 envelope', 'POST', '/auth/login', { body: { email: ACC.customer[0], password: 'nope-nope' } }, 401);
    const a = await loginAs(...ACC.customer, g, 'customer (fresh pair for refresh)');
    if (a) {
      const rf = await expect(g, 'refresh rotates', 'POST', '/auth/refresh', { body: { refreshToken: a.refreshToken } }, 200,
        (d) => (d?.accessToken && d?.refreshToken && d.refreshToken !== a.refreshToken) || 'no rotated pair');
      await expect(g, 'reused refresh rejected', 'POST', '/auth/refresh', { body: { refreshToken: a.refreshToken } }, 401);
      const rotated = data(rf)?.refreshToken;
      if (rotated) {
        // Reuse of an old token SHOULD burn the whole family (RFC 6819 §5.2.2.3); record what happens.
        const fam = await call('POST', '/auth/refresh', { body: { refreshToken: rotated } });
        info(g, 'after reuse, the rotated sibling refresh', fam.status === 200 ? 'still valid (no family revocation on reuse)' : `revoked (${fam.status})`);
        const next = data(fam)?.refreshToken || rotated;
        await expect(g, 'mobile: logout {refreshToken}', 'POST', '/auth/logout', { body: { refreshToken: next } }, 200);
        await expect(g, 'refresh after logout → 401', 'POST', '/auth/refresh', { body: { refreshToken: next } }, 401);
      }
      await expect(g, 'refresh missing token → 422', 'POST', '/auth/refresh', { body: {} }, [400, 422]);
    }
    // step-up (tasker_wallet/step_up_sheet + kyco_api_tasker.dart stepUp)
    await expect(g, 'step-up status', 'GET', '/auth/step-up', { token: C }, 200,
      (d) => (typeof d?.fresh === 'boolean' && typeof d?.hasUsablePassword === 'boolean') || JSON.stringify(d));
    await expect(g, 'mobile: step-up wrong password → 422', 'POST', '/auth/step-up', { token: C, body: { method: 'password', password: 'wrong-pass' } }, 422);
    await expect(g, 'mobile: step-up password', 'POST', '/auth/step-up', { token: C, body: { method: 'password', password: ACC.customer[1] } }, 200,
      (d) => d?.fresh === true || JSON.stringify(d));
    await expect(g, 'step-up status fresh after grant', 'GET', '/auth/step-up', { token: C }, 200, (d) => d?.fresh === true || JSON.stringify(d));
    await expect(g, 'step-up bad method → 422', 'POST', '/auth/step-up', { token: C, body: { method: 'magic' } }, 422);
    await expect(g, 'step-up no token → 401', 'POST', '/auth/step-up', { body: { method: 'password', password: 'x' } }, 401);
    // OTP request (stub sender in dev): 200 {channel:'stub'} or a clean 4xx/502 envelope — never 500.
    const otpOk = (d, r) => (r.status !== 500) || 'HTTP 500';
    await expect(g, 'OTP request purpose login', 'POST', '/auth/otp/request', { body: { phone: '+84901110002', purpose: 'login' } }, [200, 400, 422, 429, 502], otpOk);
    await expect(g, 'mobile: OTP request purpose phone_verification (step_up_sheet)', 'POST', '/auth/otp/request', { body: { phone: '+84901110002', purpose: 'phone_verification' } }, [200, 400, 422, 429, 502], otpOk);
    await expect(g, 'OTP request invalid phone → 422', 'POST', '/auth/otp/request', { body: { phone: '123', purpose: 'login' } }, [400, 422]);

    // banned user + revoked session
    const ban = await loginAs(TEMP.ban, TEMP_PW, g, 'temp ban user');
    const rev = await loginAs(TEMP.revoke, TEMP_PW, g, 'temp revoke user');
    if (ban && rev) {
      await expect(g, 'temp ban user /me before ban', 'GET', '/me', { token: ban.accessToken }, 200);
      await expect(g, 'temp revoke user /me before bump', 'GET', '/me', { token: rev.accessToken }, 200);
      sql(`update users set is_active=false where id=${banId}`);
      sql(`update users set token_version=token_version+1 where id=${revokeId}`);
      console.log('… waiting 31s for the 30s ban/epoch cache (lib/auth/context.ts BAN_CHECK_TTL_MS)');
      await sleep(31_000);
      await expect(g, 'banned: existing access token → 401', 'GET', '/me', { token: ban.accessToken }, 401);
      const br = await expect(g, 'banned: refresh must fail', 'POST', '/auth/refresh', { body: { refreshToken: ban.refreshToken } }, [401, 403]);
      if (br.status === 200 && data(br)?.accessToken) {
        await expect(g, 'banned: access token minted by refresh → 401', 'GET', '/me', { token: data(br).accessToken }, 401);
      }
      await expect(g, 'banned: login refused', 'POST', '/auth/login', { body: { email: TEMP.ban, password: TEMP_PW } }, [401, 403]);
      await expect(g, 'token_version bump: old access token → 401', 'GET', '/me', { token: rev.accessToken }, 401);
      const rr = await call('POST', '/auth/refresh', { body: { refreshToken: rev.refreshToken } });
      info(g, 'token_version bump: pre-bump refresh token', rr.status === 200 ? 'still rotates (200) — refresh tokens are not tied to the epoch' : `rejected (${rr.status})`);
      sql(`update users set is_active=true where id=${banId}`);
    }
  }

  let job1 = 0, booking1 = 0, job3 = 0, booking3 = 0;

  // ── B) lifecycle on job 1 ─────────────────────────────────────────────
  if (want('lifecycle')) {
    const g = 'lifecycle';
    // C) server validation on the booking door
    await expect('booking', 'route: amount key rejected', 'POST', '/bookings', { token: C, body: { ...mobileBookingBody(serviceId, '08:00'), totalVnd: 1 } }, 422);
    const b1 = await createBooking(C, serviceId, '08:00', 'job1');
    booking1 = b1.bookingId;
    await expect('booking', 'mobile: same idempotencyKey → dedup', 'POST', '/bookings', { token: C, body: b1.body }, [200, 201],
      (d) => (d?.kind === 'dedup' && d?.bookingId === booking1) || JSON.stringify(d));
    const before = Number(sql(`select count(*) from bookings`));
    const e1 = await expect('booking', 'checklist#3: empty addressLine → 422', 'POST', '/bookings', { token: C, body: mobileBookingBody(serviceId, '08:30', { addressLine: '', district: '' }) }, 422);
    const e2 = await expect('booking', 'checklist#4: unknown serviceId → 404/422', 'POST', '/bookings', { token: C, body: mobileBookingBody(999999, '08:30') }, [404, 422]);
    const inactive = Number(sql(`select coalesce(min(id),0) from services where is_active=false`));
    if (inactive) await expect('booking', `checklist#3: inactive serviceId ${inactive} → 404/422`, 'POST', '/bookings', { token: C, body: mobileBookingBody(inactive, '08:30') }, [404, 422]);
    const junk = Number(sql(`select count(*) from bookings`)) - before;
    if (junk > 0) {
      // close the junk pool jobs so they don't pollute the tasker pool
      sql(`update jobs set status='closed' where booking_id in (select id from bookings order by id desc limit ${junk}) and booking_id <> ${booking1}`);
      info('booking', 'junk bookings from validation probes', `${junk} created; their jobs closed in DB`);
    }
    void e1; void e2;

    if (booking1) {
      job1 = await findPoolJob(P, booking1, g);
      await expect('matrix', 'customer token claim → 401/403', 'POST', `/tasker/jobs/${job1}/claim`, { token: C }, [401, 403]);
      await expect(g, 'mobile: claim (no body)', 'POST', `/tasker/jobs/${job1}/claim`, { token: P }, 200,
        (d) => (d?.jobId === job1 && d?.bookingId === booking1) || JSON.stringify(d));
      await expect(g, 'claim again → 409', 'POST', `/tasker/jobs/${job1}/claim`, { token: P }, 409);
      await expect(g, 'claim missing job → 404', 'POST', '/tasker/jobs/99999999/claim', { token: P }, 404);
      await expect(g, 'GET own job detail', 'GET', `/tasker/jobs/${job1}`, { token: P }, 200);

      // Geofence: mobile booking body has no coordinates → set them in QA DB.
      const lat = +(10.7769 + (Math.random() - 0.5) * 0.004).toFixed(6);
      const lng = +(106.7009 + (Math.random() - 0.5) * 0.004).toFixed(6);
      const coordsBefore = sql(`select coalesce(address_lat::text,'null')||','||coalesce(address_lng::text,'null') from bookings where id=${booking1}`);
      info(g, 'booking address coords after mobile create', coordsBefore);
      sql(`update bookings set address_lat=${lat}, address_lng=${lng} where id=${booking1}`);

      await expect(g, 'mobile: start-tracking (no body)', 'POST', `/tasker/jobs/${job1}/start-tracking`, { token: P }, 201,
        (d) => (d?.sessionId > 0 && d?.bookingId === booking1) || JSON.stringify(d));
      await expect(g, 'start-tracking twice → 409', 'POST', `/tasker/jobs/${job1}/start-tracking`, { token: P }, 409);
      await expect(g, 'check-in wrong key (lng instead of lon) → 422', 'POST', `/tasker/jobs/${job1}/check-in`, { token: P, body: { lat, lng, accuracyM: 12 } }, 422);
      await expect(g, 'check-in 5km away → 422 geofence', 'POST', `/tasker/jobs/${job1}/check-in`, { token: P, body: { lat: lat + 0.045, lon: lng, accuracyM: 12 } }, 422);
      await expect(g, 'check-in low accuracy (500m) → 422', 'POST', `/tasker/jobs/${job1}/check-in`, { token: P, body: { lat, lon: lng, accuracyM: 500 } }, 422);
      await expect(g, 'mobile: check-in {lat,lon,accuracyM}', 'POST', `/tasker/jobs/${job1}/check-in`, { token: P, body: { lat, lon: lng, accuracyM: 12 } }, 201,
        (d) => (d?.geofenceWithin === true && d?.lateFine?.fine === 0) || JSON.stringify(d));
      await expect(g, 'check-in twice → 409', 'POST', `/tasker/jobs/${job1}/check-in`, { token: P, body: { lat, lon: lng, accuracyM: 12 } }, 409);

      // Media: the app (kyco_api_tasker.dart mediaUploadIntentBody) sends {category, entityType:'booking', entityId,
      // fileName, mimeType, sizeBytes, documentKind?} — the same body as the route contract below.
      // Full upload: request-upload → PUT bytes to the signed URL → finalize {mediaId}. Needs GCS or the dev
      // local fallback (NODE_ENV!=production + KYCO_LOCAL_MEDIA_SECRET); a prod build without GCS → 503.
      const JPEG = Buffer.from('/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=', 'base64');
      // VRF-9 (a5c2d24): request-upload has its own per-user limiter (30/min) — no upload pacing; a whole
      // job's photo set (2 before + 1 mid + 2 after) goes back-to-back and must never 429.
      const upload = async (category, name) => {
        const ru = await expect(g, `route: media request-upload ${category}/${name}`, 'POST', '/media/request-upload',
          { token: P, body: { category, entityType: 'booking', entityId: booking1, fileName: name, mimeType: 'image/jpeg', sizeBytes: JPEG.length } }, 201,
          (d) => (d?.assetId > 0 && typeof d?.uploadUrl === 'string') || JSON.stringify(d));
        const d = data(ru);
        if (!d?.uploadUrl) return 0;
        const put = await fetch(d.uploadUrl, { method: 'PUT', headers: { 'Content-Type': d.requiredContentType || 'image/jpeg' }, body: JPEG });
        record(g, `PUT signed upload URL ${name}`, put.status >= 200 && put.status < 300, `HTTP ${put.status}`);
        const fin = await expect(g, `route: media finalize {mediaId} ${name}`, 'POST', '/media/finalize', { token: P, body: { mediaId: d.assetId } }, 200);
        return fin.status === 200 ? d.assetId : 0;
      };

      // Photos: {slot, mediaIds} only (MQA-43: legacy urls refused)
      await expect(g, 'checklist#3/#4: photos with unknown mediaId → 422', 'POST', `/tasker/jobs/${job1}/photos`,
        { token: P, body: { slot: 'before', mediaIds: [99999999] } }, [404, 422]);
      await expect(g, 'photos invalid slot → 422', 'POST', `/tasker/jobs/${job1}/photos`, { token: P, body: { slot: 'during', mediaIds: [1] } }, 422);
      await expect(g, 'MQA-43: external photo urls → 422', 'POST', `/tasker/jobs/${job1}/photos`, { token: P, body: { slot: 'mid', urls: ['https://evil.example/not-ours.jpg'] } }, 422);
      await expect(g, 'check-out before photos → 409', 'POST', `/tasker/jobs/${job1}/check-out`, { token: P, body: { lat, lng, accuracyM: 12 } }, 409);
      const b1 = await upload('checkin', 'before-1.jpg'), b2 = await upload('checkin', 'before-2.jpg');
      await expect(g, 'photos before x2 (mediaIds)', 'POST', `/tasker/jobs/${job1}/photos`, { token: P, body: { slot: 'before', mediaIds: [b1, b2] } }, 200, (d) => d?.stored === 2 || JSON.stringify(d));
      await expect(g, 'photos before re-send dedups', 'POST', `/tasker/jobs/${job1}/photos`, { token: P, body: { slot: 'before', mediaIds: [b1] } }, 200, (d) => d?.stored === 2 || JSON.stringify(d));
      await expect(g, 'photos: checkin media in "mid" slot (wrong category) → 422', 'POST', `/tasker/jobs/${job1}/photos`, { token: P, body: { slot: 'mid', mediaIds: [b1] } }, 422);
      const m1 = await upload('checkout', 'mid-1.jpg');
      await expect(g, 'photos mid x1', 'POST', `/tasker/jobs/${job1}/photos`, { token: P, body: { slot: 'mid', mediaIds: [m1] } }, 200, (d) => d?.stored === 1 || JSON.stringify(d));
      await expect(g, 'complete before check-out → 4xx', 'POST', `/tasker/jobs/${job1}/complete`, { token: P }, [409, 422]);
      await expect(g, 'check-out wrong key (lon instead of lng) → 422', 'POST', `/tasker/jobs/${job1}/check-out`, { token: P, body: { lat, lon: lng, accuracyM: 12 } }, 422);
      await expect(g, 'mobile: check-out {lat,lng,accuracyM}', 'POST', `/tasker/jobs/${job1}/check-out`, { token: P, body: { lat, lng, accuracyM: 12 } }, 200,
        (d) => (d?.bookingId === booking1) || JSON.stringify(d));
      await expect(g, 'complete without after photos → 409/422', 'POST', `/tasker/jobs/${job1}/complete`, { token: P }, [409, 422]);
      const a1 = await upload('checkout', 'after-1.jpg'), a2 = await upload('checkout', 'after-2.jpg');
      await expect(g, 'photos after x2 (mediaIds)', 'POST', `/tasker/jobs/${job1}/photos`, { token: P, body: { slot: 'after', mediaIds: [a1, a2] } }, 200, (d) => d?.stored === 2 || JSON.stringify(d));
      await expect(g, 'mobile: complete (no body)', 'POST', `/tasker/jobs/${job1}/complete`, { token: P }, 200, (d) => (d?.bookingId === booking1) || JSON.stringify(d));
      await expect(g, 'complete twice → 409', 'POST', `/tasker/jobs/${job1}/complete`, { token: P }, 409);
      // customer side: READ only (confirm-completion / cash-received are money-adjacent → not called)
      await expect(g, 'customer reads booking status', 'GET', `/bookings/${booking1}`, { token: C }, 200, (d) => {
        const s = String(d?.status ?? d?.booking?.status ?? '').toUpperCase();
        return s === 'AWAITING_CUSTOMER_CONFIRMATION' || `status=${s}`;
      });
      const extra = sql(`select count(*) from tasker_check_ins where job_id=${job1} and event_kind='departure'`);
      info(g, 'departure rows for job1', extra);
    }
  }

  // ── availability (C: PUT semantics) ───────────────────────────────────
  if (want('availability')) {
    const g = 'availability';
    const orig = data(await call('GET', '/tasker/availability', { token: P }));
    console.log('availability before:', JSON.stringify(orig).slice(0, 200));
    const weekly = { force: false, days: { [String(RUN_DOW)]: [{ start: 420, end: 1080 }], [String((RUN_DOW + 3) % 7)]: [{ start: 480, end: 720 }] } };
    await expect(g, 'mobile: weekly {force,days}', 'PUT', '/tasker/availability/weekly', { token: P, body: weekly }, 200, (d) => d?.saved === true || JSON.stringify(d));
    const after = data(await call('GET', '/tasker/availability', { token: P }));
    record(g, 'weekly persisted (GET shows slots)', JSON.stringify(after).includes('420') || JSON.stringify(after).includes('1080'), JSON.stringify(after).slice(0, 160));
    await expect(g, 'weekly invalid slot (start>=end) → 422', 'PUT', '/tasker/availability/weekly', { token: P, body: { days: { '1': [{ start: 600, end: 500 }] } } }, 422);
    await expect(g, 'weekly bad day key → 422', 'PUT', '/tasker/availability/weekly', { token: P, body: { days: { '9': [] } } }, 422);
    const dateBody = { date: vnDate(RUN_DAY + 1), force: false, slots: [{ start: 540, end: 720 }] };
    await expect(g, 'mobile: date {date,force,slots}', 'PUT', '/tasker/availability/date', { token: P, body: dateBody }, 200, (d) => d?.saved === true || JSON.stringify(d));
    await expect(g, 'date bad format → 422', 'PUT', '/tasker/availability/date', { token: P, body: { date: '10/10/2026', slots: [] } }, 422);
    await expect(g, 'date missing slots → 422', 'PUT', '/tasker/availability/date', { token: P, body: { date: dateBody.date } }, 422);
    // checklist #2/#3: PUT without the required `days` must not wipe the grid
    const rowsBefore = Number(sql(`select count(*) from tasker_availability where tasker_id=1 and specific_date is null`));
    const wipe = await call('PUT', '/tasker/availability/weekly', { token: P, body: { force: false } });
    const rowsAfter = Number(sql(`select count(*) from tasker_availability where tasker_id=1 and specific_date is null`));
    record(g, 'checklist#2/#3: PUT weekly without `days` → 422, grid untouched', [400, 422].includes(wipe.status) && rowsAfter === rowsBefore,
      `${short(wipe)}; weekly rows ${rowsBefore}→${rowsAfter}`);
    await expect('matrix', 'customer token weekly → 401/403', 'PUT', '/tasker/availability/weekly', { token: C, body: weekly }, [401, 403]);
    await expect('matrix', 'customer token date → 401/403', 'PUT', '/tasker/availability/date', { token: C, body: dateBody }, [401, 403]);
    // restore to the original (empty in the seeded QA DB) state
    await call('PUT', '/tasker/availability/date', { token: P, body: { date: dateBody.date, force: true, slots: [] } });
    await call('PUT', '/tasker/availability/weekly', { token: P, body: { force: true, days: {} } });
  }

  // ── decline on job 2 ─────────────────────────────────────────────────
  if (want('decline')) {
    const g = 'decline';
    const b2 = await createBooking(C, serviceId, '11:00', 'job2');
    if (b2.bookingId) {
      const job2 = await findPoolJob(P, b2.bookingId, g);
      await expect(g, 'decline unassigned pool job → 404', 'POST', `/tasker/jobs/${job2}/decline`, { token: P, body: { reason: 'QA' } }, 404);
      // A pool claim auto-confirms to `active`; decline needs an ASSIGNED `pending`
      // job (direct dispatch) → assign in QA DB.
      sql(`update jobs set tasker_id=1 where id=${job2}`);
      const pen = sql(`select penalty_score from taskers where id=1`);
      if (P2) await expect('matrix', 'tasker2 decline P1 job → 404', 'POST', `/tasker/jobs/${job2}/decline`, { token: P2, body: { reason: 'x' } }, 404);
      await expect('matrix', 'customer token decline → 401/403', 'POST', `/tasker/jobs/${job2}/decline`, { token: C, body: { reason: 'x' } }, [401, 403]);
      await expect(g, 'mobile: decline {reason}', 'POST', `/tasker/jobs/${job2}/decline`, { token: P, body: { reason: 'QA flows decline' } }, 200,
        (d) => (d?.branch === 'pre-slot' && d?.jobId === job2) || JSON.stringify(d));
      await expect(g, 'decline again (back in pool) → 404', 'POST', `/tasker/jobs/${job2}/decline`, { token: P, body: {} }, 404);
      info(g, 'tasker 1 penalty_score', `${pen} → ${sql('select penalty_score from taskers where id=1')} (reset to ${pen} in DB)`);
      sql(`update taskers set penalty_score=${Number(pen) || 0} where id=1`);
      sql(`update jobs set status='closed' where id=${job2}`);
    }
  }

  // ── job 3: message, complaint, goals, support, IDOR matrix ──────────
  if (want('job3') || want('matrix')) {
    const g = 'job3';
    const b3 = await createBooking(C, serviceId, '14:00', 'job3');
    booking3 = b3.bookingId;
    if (booking3) {
      job3 = await findPoolJob(P, booking3, g);
      await expect(g, 'claim job3', 'POST', `/tasker/jobs/${job3}/claim`, { token: P }, 200);
      await expect(g, 'mobile: message {body}', 'POST', `/tasker/jobs/${job3}/message`, { token: P, body: { body: 'Xin chào, em là CTV QA' } }, 201,
        (d) => d?.bookingId === booking3 || JSON.stringify(d));
      await expect(g, 'message empty body → 422', 'POST', `/tasker/jobs/${job3}/message`, { token: P, body: { body: '  ' } }, 422);
      await expect(g, 'message missing job → 404', 'POST', '/tasker/jobs/99999999/message', { token: P, body: { body: 'x' } }, 404);
      await expect(g, 'mobile: complaint {category:other, description}', 'POST', `/tasker/jobs/${job3}/complaint`, { token: P, body: { category: 'other', description: 'Khách không có nhà (QA)' } }, 201,
        (d) => d?.id > 0 || JSON.stringify(d));
      await expect(g, 'complaint without description → 422 (mobile blocks empty client-side)', 'POST', `/tasker/jobs/${job3}/complaint`, { token: P, body: { category: 'other' } }, 422);
      // SOS: the app calls POST /sos {jobId, lat, lng, accuracyM, category:'safety', note} (kyco_api.dart triggerSos),
      // no longer a complaint. Resolve any open SOS of this tasker first (90 s dedup would answer 200 deduped).
      sql(`update sos_events set status='resolved', resolved_at=now() where status <> 'resolved' and triggered_by_user_id=(select id from users where email='${ACC.tasker[0]}')`);
      await expect(g, 'mobile: SOS POST /sos {jobId,lat,lng,accuracyM,category:safety,note}', 'POST', '/sos',
        { token: P, body: { jobId: job3, lat: 10.7769, lng: 106.7009, accuracyM: 15, category: 'safety', note: 'SOS — tasker pressed the emergency button in the app (QA)' } }, 201,
        (d) => (d?.jobAttached === true) || JSON.stringify(d));
      sql(`update sos_events set status='resolved', resolved_at=now() where status <> 'resolved' and notes like '%(QA)%' and triggered_by_user_id=(select id from users where email='${ACC.tasker[0]}')`);
      await expect(g, 'complaint bad category → 422 fields.category', 'POST', `/tasker/jobs/${job3}/complaint`, { token: P, body: { category: 'zzz', description: 'Khách không có nhà (QA) — bad category' } }, 422,
        (_d, r) => ('category' in (r?.json?.fields ?? {})) || JSON.stringify(r?.json?.fields));
      await expect(g, 'complaint description < 20 chars → 422 fields.description', 'POST', `/tasker/jobs/${job3}/complaint`, { token: P, body: { category: 'other', description: 'quá ngắn' } }, 422);
      await expect(g, 'complaint missing job → 404', 'POST', '/tasker/jobs/99999999/complaint', { token: P, body: { category: 'other', description: 'Khách không có nhà (QA) — missing job' } }, 404);
    }
  }

  if (want('goals')) {
    const g = 'goals';
    const key = `${RUN_DATE.slice(0, 4)}-W${String(10 + RUN_DAY).padStart(2, '0')}`;
    await expect(g, 'mobile: PUT goals {periodKind,periodKey,targetJobs,targetVnd}', 'PUT', '/tasker/goals', { token: P, body: { periodKind: 'week', periodKey: key, targetJobs: 12, targetVnd: 3_000_000 } }, 200);
    await expect(g, 'goal persisted', 'GET', '/tasker/goals', { token: P }, 200,
      (d) => (Array.isArray(d) && d.some((x) => x.periodKey === key && Number(x.targetJobs) === 12 && Number(x.targetVnd) === 3_000_000)) || JSON.stringify(d).slice(0, 160));
    await expect(g, 'mobile default periodKey "" → 422', 'PUT', '/tasker/goals', { token: P, body: { periodKind: 'week', periodKey: '', targetJobs: 0, targetVnd: 0 } }, 422);
    await expect(g, 'bad periodKind → 422', 'PUT', '/tasker/goals', { token: P, body: { periodKind: 'year', periodKey: key, targetJobs: 1, targetVnd: 1 } }, 422);
    const partial = await call('PUT', '/tasker/goals', { token: P, body: { periodKind: 'week', periodKey: key, targetJobs: 20 } });
    const vnd = sql(`select target_vnd from tasker_goals where tasker_id=1 and period_kind='week' and period_key=${lit(key)}`);
    record(g, 'checklist#2: PUT without targetVnd → 422 (not silently zeroed)', [400, 422].includes(partial.status) || Number(vnd) === 3_000_000,
      `${short(partial)}; target_vnd now ${vnd}`);
    await expect(g, 'negative target clamps or 422', 'PUT', '/tasker/goals', { token: P, body: { periodKind: 'week', periodKey: key, targetJobs: -5, targetVnd: 1.5 } }, [200, 422]);
    await expect('matrix', 'customer token PUT goals → 401/403', 'PUT', '/tasker/goals', { token: C, body: { periodKind: 'week', periodKey: key, targetJobs: 1, targetVnd: 1 } }, [401, 403]);
  }

  if (want('support')) {
    const g = 'support';
    await expect(g, 'mobile: ticket {subject,body,category,priority}', 'POST', '/support/tickets', { token: P, body: { subject: 'Lỗi rút tiền QA', body: 'Mô tả chi tiết (flows-qa)', category: 'wallet', priority: 'normal' } }, 201, (d) => d?.id > 0 || JSON.stringify(d));
    await expect(g, 'mobile: ticket without body (client omits empty)', 'POST', '/support/tickets', { token: P, body: { subject: 'Câu hỏi chính sách QA', category: 'policy', priority: 'high' } }, 201);
    await expect(g, 'subject < 5 chars → 422', 'POST', '/support/tickets', { token: P, body: { subject: 'ab', category: 'tech' } }, 422);
    await expect(g, 'bad category → 422', 'POST', '/support/tickets', { token: P, body: { subject: 'Hello there', category: 'zzz' } }, 422);
    await expect(g, 'bad priority → 422', 'POST', '/support/tickets', { token: P, body: { subject: 'Hello there', category: 'tech', priority: 'p0' } }, 422);
    await expect(g, 'ticket listed in /tasker/support', 'GET', '/tasker/support', { token: P }, 200,
      (d) => JSON.stringify(d).includes('Lỗi rút tiền QA') || 'not listed');
    await expect(g, 'no token → 401', 'POST', '/support/tickets', { body: { subject: 'Hello there' } }, 401);
  }

  // ── role / IDOR matrix on job3 (active, owned by tasker 1) ─────────
  if (want('matrix') && job3) {
    const g = 'matrix';
    const snap = () => sql(`select status||'|'||coalesce(tasker_id::text,'')||'|'||coalesce(jsonb_array_length(before_photos)::text,'0') from jobs where id=${job3}`)
      + '|' + sql(`select count(*) from messages where booking_id=${booking3}`) + '|' + sql(`select count(*) from disputes where booking_id=${booking3}`);
    const s0 = snap();
    const doors = [
      ['claim', undefined], ['confirm', undefined], ['decline', { reason: 'x' }], ['start-tracking', undefined],
      ['check-in', { lat: 10.77, lon: 106.7, accuracyM: 10 }], ['check-out', { lat: 10.77, lng: 106.7, accuracyM: 10 }],
      ['photos', { slot: 'before', mediaIds: [1] }], ['complete', undefined],
      ['message', { body: 'idor' }], ['complaint', { category: 'other', description: 'idor probe — at least twenty chars' }],
    ];
    for (const [door, body] of doors) {
      await expect(g, `customer token ${door} → 401/403`, 'POST', `/tasker/jobs/${job3}/${door}`, { token: C, body }, [401, 403]);
    }
    if (P2) {
      for (const [door, body] of doors) {
        // claim on an already-claimed job is a legit 409 (pool semantics), everything else must hide the job.
        await expect(g, `tasker2 ${door} on P1 job → 404`, 'POST', `/tasker/jobs/${job3}/${door}`, { token: P2, body }, door === 'claim' ? [404, 409] : [404]);
      }
      await expect(g, 'tasker2 GET P1 job → 404', 'GET', `/tasker/jobs/${job3}`, { token: P2 }, [404]);
    } else {
      info(g, 'tasker2', 'not linked — IDOR-by-tasker skipped');
    }
    for (const [door, body] of doors) {
      await expect(g, `tasker ${door} on missing job → 404`, 'POST', `/tasker/jobs/99999999/${door}`, { token: P, body }, [404]);
    }
    const s1 = snap();
    record(g, 'job3 row/messages/disputes unchanged after IDOR attempts', s0 === s1, `${s0} → ${s1}`);
  }

  // cleanup: close flows job3 so it doesn't block later runs' time-conflict check
  if (job3) sql(`update jobs set status='closed' where id=${job3}`);

  const failed = results.filter((r) => !r.ok);
  const checks = results.filter((r) => !r.info);
  console.log(`\n${checks.length - failed.length}/${checks.length} passed`);
  if (process.env.FLOWS_JSON) {
    const fs = await import('node:fs');
    fs.writeFileSync(process.env.FLOWS_JSON, JSON.stringify({ base: BASE, at: new Date().toISOString(), runDate: RUN_DATE, results }, null, 2));
  }
  process.exit(failed.length ? 1 : 0);
}
main();
