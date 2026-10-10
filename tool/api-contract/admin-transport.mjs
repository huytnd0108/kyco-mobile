#!/usr/bin/env node
// /api/admin/v1 transport regression (Bearer + web-cookie, CSRF, step-up) +
// WS7 admin-ops new-route contract — QA for the web-API-only migration.
//
//   ORIGIN_BASE=http://localhost:4142 node tool/api-contract/admin-transport.mjs
//
// Part A (transport, ws7-shell-S2): refused-before-state-change checks only.
// Part B (admin-ops routes, tip e6b9869): role 403s + STEP_UP_REQUIRED BEFORE
//   the admin grant, then (after a password step-up) 422/404 validation and
//   SAFE happy paths that are restored afterwards:
//     - flags/[name]: PUT dispatch_ml_enabled = its default (false); the
//       site_settings row is deleted again if it did not exist before.
//     - flags/disable-payments + flags/restore-defaults: authz / scope /
//       step-up ONLY — never executed (restore-defaults would reset
//       api_mobile_v1_enabled → mobile API 503 for every tester).
//     - catalog/services/:id/image: upload 1x1 PNG, then image_url restored by SQL.
//     - seo: PUT, partial-PUT wipe probe, then the original values restored.
//     - webhooks/:id/test: temporary https://example.com webhook, deleted after.
// NOTE: the step-up grant is per USER in Redis (TTL) — after this run
// admin@qa.local is "fresh" for every tester until it expires.
// Audit-row checks shell out to `docker exec appdroid-pg psql` (PSQL_DB).
import { execFileSync } from 'node:child_process';

const ORIGIN = process.env.ORIGIN_BASE || 'http://localhost:4142';
if (/kyco\.vn/.test(ORIGIN)) { console.error('QA backends only'); process.exit(2); }
const PACE = Number(process.env.SMOKE_PACE_MS || 2100);
const PSQL_DB = process.env.PSQL_DB || 'kyco_wapi_mobileqa';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const ACC = {
  customer: ['demo@demo.local', 'demo12345'],
  tasker: ['tasker@qa.local', 'TaskerQa12345!'],
  admin: ['admin@qa.local', 'Admin12345qa'],
};
const results = [];
const rec = (name, ok, detail) => {
  results.push({ name, ok });
  const tag = ok === null ? 'SKIP' : ok ? 'PASS' : 'FAIL';
  console.log(`${tag}  ${name}${ok ? '' : `  — ${detail}`}`);
};

async function req(method, path, { token, cookie, body, origin, form, multipart, headers = {} } = {}) {
  await sleep(PACE);
  const h = { Accept: 'application/json', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  if (cookie) h.Cookie = cookie;
  if (origin) h.Origin = origin;
  let b;
  if (multipart) b = multipart;
  else if (form) { h['Content-Type'] = 'application/x-www-form-urlencoded'; b = new URLSearchParams(form).toString(); }
  else if (body !== undefined) { h['Content-Type'] = 'application/json'; b = JSON.stringify(body); }
  const res = await fetch(ORIGIN + path, { method, headers: h, body: b, redirect: 'manual' });
  const text = await res.text();
  let json = null; try { json = JSON.parse(text); } catch { /* */ }
  return { status: res.status, json, text: text.slice(0, 240), setCookie: res.headers.getSetCookie?.() ?? [], location: res.headers.get('location') };
}
// Last Set-Cookie wins per name (the server emits authjs.csrf-token twice in one response).
const jar = (cookies) => [...new Map(cookies.map((c) => c.split(';')[0]).map((kv) => [kv.split('=')[0], kv])).values()].join('; ');

function psql(sql) {
  try {
    return execFileSync('docker', ['exec', 'appdroid-pg', 'psql', '-U', 'postgres', '-d', PSQL_DB, '-Atc', sql], { encoding: 'utf8' }).trim();
  } catch (e) { return `__ERR__ ${e.message.split('\n')[0]}`; }
}
const lit = (s) => `'${String(s).replace(/'/g, "''")}'`;

async function bearer(role) {
  const [email, password] = ACC[role];
  const r = await req('POST', '/api/v1/auth/login', { body: { email, password } });
  return r.json?.data?.accessToken;
}
async function webCookie(role) {
  const [email, password] = ACC[role];
  const c = await req('GET', '/api/auth/csrf');
  const csrfToken = c.json?.csrfToken; let cookies = c.setCookie;
  const r = await req('POST', '/api/auth/callback/credentials', { cookie: jar(cookies), form: { csrfToken, email, password, json: 'true' } });
  cookies = [...cookies, ...r.setCookie];
  const sess = jar(cookies);
  if (!/session-token=/.test(sess)) {
    // Auth.js reports authorize() exceptions (e.g. DB pool exhaustion) as ?error=Configuration.
    console.log(`  (${role} cookie login failed: HTTP ${r.status} location=${r.location})`);
    return null;
  }
  return sess;
}
function check(name, r, statuses, codeWanted) {
  const okS = statuses.includes(r.status);
  const okC = !codeWanted || r.json?.code === codeWanted;
  rec(name, okS && okC, `HTTP ${r.status} code=${r.json?.code} ${r.text}`);
  return r;
}

// Every admin-ops route under test: method, path, a body that WOULD be valid.
const PNG_1x1 = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
const pngForm = () => { const fd = new FormData(); fd.append('file', new Blob([PNG_1x1], { type: 'image/png' }), 'qa.png'); return fd; };
const NEW_ROUTES = [
  ['POST', '/api/admin/v1/catalog/categories/1/image', { multipart: true }],
  ['PUT', '/api/admin/v1/catalog/categories/1/image', { body: { mediaId: 1 } }],
  ['DELETE', '/api/admin/v1/catalog/categories/1/image', {}],
  ['POST', '/api/admin/v1/catalog/services/1/image', { multipart: true }],
  ['PUT', '/api/admin/v1/catalog/services/1/image', { body: { mediaId: 1 } }],
  ['DELETE', '/api/admin/v1/catalog/services/1/image', {}],
  ['PUT', '/api/admin/v1/catalog/subcategories/1/image', { body: { mediaId: 1 } }],
  ['DELETE', '/api/admin/v1/catalog/subcategories/1/image', {}],
  ['PUT', '/api/admin/v1/flags/dispatch_ml_enabled', { body: { value: false } }],
  ['POST', '/api/admin/v1/flags/disable-payments', {}],
  ['POST', '/api/admin/v1/flags/restore-defaults', {}],
  ['POST', '/api/admin/v1/jobs/sync-notifications', {}],
  ['POST', '/api/admin/v1/resync/jobs', {}],
  ['PUT', '/api/admin/v1/seo', { body: { route: '/', title: 'qa' } }],
  ['POST', '/api/admin/v1/webhooks/999999/test', {}],
];
const optsFor = (o) => (o.multipart ? { multipart: pngForm() } : o.body !== undefined ? { body: o.body } : {});

(async () => {
  const RUN_START_AUDIT = Number(psql(`select coalesce(max(id),0) from kycore.admin_audit`)) || 0;
  const A = await bearer('admin'), C = await bearer('customer'), P = await bearer('tasker');
  rec('bearer logins', !!(A && C && P), 'login failed');
  const su = await req('GET', '/api/v1/auth/step-up', { token: A });
  const preFresh = su.json?.data?.fresh === true;
  if (preFresh) console.log('  (admin already has a fresh step-up grant — STEP_UP_REQUIRED checks are SKIPPED)');
  const stepUpCheck = (name, r) => (preFresh ? rec(name, null, 'grant already fresh') : check(name, r, [401, 403], 'STEP_UP_REQUIRED'));

  // ── Part A — transport ─────────────────────────────────────────────────
  check('admin Bearer GET /admin/v1/dashboard', await req('GET', '/api/admin/v1/dashboard', { token: A }), [200]);
  check('admin Bearer GET /admin/v1/payments/dashboard', await req('GET', '/api/admin/v1/payments/dashboard', { token: A }), [200]);
  check('customer Bearer → 403', await req('GET', '/api/admin/v1/dashboard', { token: C }), [403]);
  check('tasker Bearer → 403', await req('GET', '/api/admin/v1/dashboard', { token: P }), [403]);
  check('no auth → 401', await req('GET', '/api/admin/v1/dashboard'), [401], 'AUTH_REQUIRED');
  // Money write without a fresh step-up must be refused BEFORE touching the row (id 999999 never exists).
  stepUpCheck('admin Bearer payout resolve w/o step-up (foreign Origin ignored for Bearer) → STEP_UP_REQUIRED',
    await req('POST', '/api/admin/v1/payouts/999999', { token: A, body: { action: 'reject', reason: 'qa' }, origin: 'https://evil.example' }));

  const ck = await webCookie('admin');
  rec('admin web cookie login', !!ck, 'no session cookie');
  if (ck) {
    check('admin cookie GET /admin/v1/dashboard', await req('GET', '/api/admin/v1/dashboard', { cookie: ck }), [200]);
    check('admin cookie mutation, foreign Origin → 403 CSRF_FAILED', await req('POST', '/api/admin/v1/payouts/999999', { cookie: ck, body: { action: 'reject', reason: 'qa' }, origin: 'https://evil.example' }), [403], 'CSRF_FAILED');
    check('admin cookie mutation, no Origin/Referer → 403 CSRF_FAILED', await req('POST', '/api/admin/v1/payouts/999999', { cookie: ck, body: { action: 'reject', reason: 'qa' } }), [403], 'CSRF_FAILED');
    check('admin cookie mutation, Origin "null" → 403 CSRF_FAILED', await req('POST', '/api/admin/v1/payouts/999999', { cookie: ck, body: { action: 'reject', reason: 'qa' }, origin: 'null' }), [403], 'CSRF_FAILED');
    stepUpCheck('admin cookie mutation, same Origin, no step-up → STEP_UP_REQUIRED', await req('POST', '/api/admin/v1/payouts/999999', { cookie: ck, body: { action: 'reject', reason: 'qa' }, origin: ORIGIN }));
    check('admin cookie new route (disable-payments), foreign Origin → 403 CSRF_FAILED', await req('POST', '/api/admin/v1/flags/disable-payments', { cookie: ck, origin: 'https://evil.example' }), [403], 'CSRF_FAILED');
  }
  const cc = await webCookie('customer');
  if (cc) check('customer cookie → 403', await req('GET', '/api/admin/v1/dashboard', { cookie: cc }), [403]);

  // ── Part B — admin-ops new routes: role + step-up gates (pre-grant) ───────
  for (const [m, p, o] of NEW_ROUTES) {
    check(`customer Bearer ${m} ${p} → 403`, await req(m, p, { token: C, ...optsFor(o) }), [403], 'FORBIDDEN');
    check(`tasker Bearer ${m} ${p} → 403`, await req(m, p, { token: P, ...optsFor(o) }), [403], 'FORBIDDEN');
    // SAFETY: with a pre-existing fresh grant the request would EXECUTE (restore-defaults turned
    // api_mobile_v1_enabled OFF in the lab on 2026-10-10) — so it is not sent at all.
    if (preFresh) rec(`admin Bearer ${m} ${p} w/o step-up → STEP_UP_REQUIRED`, null, 'grant already fresh — request NOT sent');
    else stepUpCheck(`admin Bearer ${m} ${p} w/o step-up → STEP_UP_REQUIRED`, await req(m, p, { token: A, ...optsFor(o) }));
  }
  const killAudits = psql(`select count(*) from kycore.admin_audit where action in ('admin.flags.disable_payments','admin.flags.restore_defaults') and id > ${RUN_START_AUDIT}`);
  rec('refused disable-payments/restore-defaults wrote no audit row & no flag change', killAudits === '0'
    && psql(`select count(*) from kycore.site_settings where key in ('feature.payment_vnpay_enabled','feature.payment_momo_enabled','feature.payment_wallet_enabled')`) === '0', `audit rows=${killAudits}`);

  // ── Step-up (password, Bearer transport) ──────────────────────────────────
  check('step-up wrong password → 422', await req('POST', '/api/v1/auth/step-up', { token: A, body: { method: 'password', password: 'nope' } }), [422]);
  const g = check('step-up admin (password) → 200', await req('POST', '/api/v1/auth/step-up', { token: A, body: { method: 'password', password: ACC.admin[1] } }), [200]);
  if (g.status !== 200) { finish(); return; }

  // ── Part B — post-grant: validation / 404 / happy paths ────────────────────
  // Catalog images. QA DB has no service_categories / service_subcategories rows.
  check('categories/999999/image DELETE unknown id → 404', await req('DELETE', '/api/admin/v1/catalog/categories/999999/image', { token: A }), [404], 'NOT_FOUND');
  check('categories/abc/image DELETE bad id → 422', await req('DELETE', '/api/admin/v1/catalog/categories/abc/image', { token: A }), [422]);
  check('categories/999999/image PUT {} → 422', await req('PUT', '/api/admin/v1/catalog/categories/999999/image', { token: A, body: {} }), [422]);
  check('categories/999999/image POST png → 404', await req('POST', '/api/admin/v1/catalog/categories/999999/image', { token: A, multipart: pngForm() }), [404]);
  check('subcategories/999999/image PUT {mediaId:1} → 404', await req('PUT', '/api/admin/v1/catalog/subcategories/999999/image', { token: A, body: { mediaId: 1 } }), [404]);
  check('subcategories/999999/image DELETE → 404', await req('DELETE', '/api/admin/v1/catalog/subcategories/999999/image', { token: A }), [404]);
  check('services/999999/image DELETE → 404', await req('DELETE', '/api/admin/v1/catalog/services/999999/image', { token: A }), [404]);
  check('services/1/image PUT {mediaId:"x"} → 422', await req('PUT', '/api/admin/v1/catalog/services/1/image', { token: A, body: { mediaId: 'x' } }), [422]);
  check('services/1/image PUT unknown media 99999999 → 404', await req('PUT', '/api/admin/v1/catalog/services/1/image', { token: A, body: { mediaId: 99999999 } }), [404]);
  check('services/1/image POST no file → 422', await req('POST', '/api/admin/v1/catalog/services/1/image', { token: A, multipart: new FormData() }), [422]);
  { const fd = new FormData(); fd.append('file', new Blob(['hello'], { type: 'text/plain' }), 'x.txt');
    check('services/1/image POST text/plain → 422', await req('POST', '/api/admin/v1/catalog/services/1/image', { token: A, multipart: fd }), [422]); }
  const svcImg = psql('select coalesce(image_url, \'__NULL__\') from kycore.services where id=1');
  const up = check('services/1/image POST png (happy) → 201', await req('POST', '/api/admin/v1/catalog/services/1/image', { token: A, multipart: pngForm() }), [201]);
  if (up.status === 201) {
    rec('services/1 image_url = media:<id> sentinel', /^media:\d+$/.test(psql('select image_url from kycore.services where id=1')), 'column not a sentinel');
    rec('audit row admin.catalog.service.image.upload', psql(`select count(*) from kycore.admin_audit where action='admin.catalog.service.image.upload' and target_id='1' and created_at > now() - interval '2 minutes'`) !== '0', 'no audit row');
  }
  if (!svcImg.startsWith('__ERR__')) psql(`update kycore.services set image_url=${svcImg === '__NULL__' ? 'null' : lit(svcImg)} where id=1`);

  // Flags.
  check('flags/not_a_flag PUT → 404 (unknown name)', await req('PUT', '/api/admin/v1/flags/not_a_flag', { token: A, body: { value: true } }), [404]);
  check('flags/dispatch_ml_enabled PUT {value:"yes"} → 422', await req('PUT', '/api/admin/v1/flags/dispatch_ml_enabled', { token: A, body: { value: 'yes' } }), [422]);
  const hadRow = psql(`select count(*) from kycore.site_settings where key='feature.dispatch_ml_enabled'`);
  check('flags/dispatch_ml_enabled PUT {value:false} (default, no-op) → 200', await req('PUT', '/api/admin/v1/flags/dispatch_ml_enabled', { token: A, body: { value: false } }), [200]);
  rec('audit row admin.flags.set', psql(`select count(*) from kycore.admin_audit where action='admin.flags.set' and target_id='dispatch_ml_enabled' and created_at > now() - interval '2 minutes'`) !== '0', 'no audit row');
  if (hadRow === '0') psql(`delete from kycore.site_settings where key='feature.dispatch_ml_enabled'`);

  // Jobs / resync (idempotent backfill + repair; no target).
  const sn = check('jobs/sync-notifications POST → 200 {sent}', await req('POST', '/api/admin/v1/jobs/sync-notifications', { token: A }), [200]);
  rec('jobs/sync-notifications returns numeric sent', typeof sn.json?.data?.sent === 'number', sn.text);
  const rj = check('resync/jobs POST → 200', await req('POST', '/api/admin/v1/resync/jobs', { token: A }), [200]);
  rec('resync/jobs result has 4 counters', ['markedOverdue', 'rerankedPool', 'convertedAssigned', 'fixedCancelClosed'].every((k) => typeof rj.json?.data?.[k] === 'number'), rj.text);

  // SEO.
  check('seo PUT {} → 422', await req('PUT', '/api/admin/v1/seo', { token: A, body: {} }), [422]);
  check('seo PUT unknown route → 422', await req('PUT', '/api/admin/v1/seo', { token: A, body: { route: '/definitely-not-a-route' } }), [422]);
  const seoKeys = ['title', 'description', 'ogImage'].map((f) => `seo:/services:${f}`);
  const seoBefore = Object.fromEntries(seoKeys.map((k) => [k, psql(`select coalesce((select value::text from kycore.site_settings where key=${lit(k)}), '__NONE__')`)]));
  check('seo PUT full body → 200', await req('PUT', '/api/admin/v1/seo', { token: A, body: { route: '/services', title: 'QA title', description: 'QA desc', ogImage: 'https://example.com/og.png' } }), [200]);
  check('seo PUT title-only → 200', await req('PUT', '/api/admin/v1/seo', { token: A, body: { route: '/services', title: 'QA title 2' } }), [200]);
  const descAfter = psql(`select value::text from kycore.site_settings where key='seo:/services:description'`);
  rec('seo partial PUT keeps description (no wipe)', /QA desc/.test(descAfter), `description after title-only PUT = ${descAfter}`);
  check('seo PUT ogImage javascript: → 422', await req('PUT', '/api/admin/v1/seo', { token: A, body: { route: '/services', title: 'x', description: 'x', ogImage: 'javascript:alert(1)' } }), [422]);
  check('seo PUT 5000-char title → 422', await req('PUT', '/api/admin/v1/seo', { token: A, body: { route: '/services', title: 'x'.repeat(5000), description: 'x', ogImage: '' } }), [422]);
  for (const [k, v] of Object.entries(seoBefore)) {
    if (v === '__NONE__') psql(`delete from kycore.site_settings where key=${lit(k)}`);
    else psql(`update kycore.site_settings set value=${lit(v)}::jsonb where key=${lit(k)}`);
  }

  // Webhooks test.
  check('webhooks/999999/test → 404', await req('POST', '/api/admin/v1/webhooks/999999/test', { token: A }), [404], 'NOT_FOUND');
  check('webhooks/abc/test → 422', await req('POST', '/api/admin/v1/webhooks/abc/test', { token: A }), [422]);
  const wc = await req('POST', '/api/admin/v1/webhooks', { token: A, body: { url: 'https://example.com/kyco-qa-webhook', events: ['*'], description: 'qa temp' } });
  // POST /webhooks returns { created, url, events } — no id (and its audit row has no target_id); look it up.
  const wid = wc.json?.data?.id ?? wc.json?.data?.webhook?.id
    ?? (wc.status === 201 ? psql(`select max(id) from kycore.webhooks where url='https://example.com/kyco-qa-webhook'`) || null : null);
  rec('create temp webhook', !!wid, `HTTP ${wc.status} ${wc.text}`);
  if (wid) {
    check(`webhooks/${wid}/test (happy) → 200`, await req('POST', `/api/admin/v1/webhooks/${wid}/test`, { token: A }), [200]);
    rec('audit row admin.webhook.test', psql(`select count(*) from kycore.admin_audit where action='admin.webhook.test' and target_id=${lit(wid)} and created_at > now() - interval '2 minutes'`) !== '0', 'no audit row');
    check(`delete temp webhook ${wid}`, await req('DELETE', `/api/admin/v1/webhooks/${wid}`, { token: A }), [200, 204]);
  }

  // Cookie transport AFTER the grant (grant is per user, either transport).
  if (ck) {
    // MQA-36 (3e9d764): money routes need an Idempotency-Key on every transport → send one so the 404 is reached.
    check('admin cookie same-Origin payout 999999 after step-up → 404 (gate passed, id unknown)', await req('POST', '/api/admin/v1/payouts/999999', { cookie: ck, body: { action: 'reject', reason: 'qa' }, origin: ORIGIN, headers: { 'Idempotency-Key': `qa-vrf1-${Date.now()}-${Math.random().toString(36).slice(2)}` } }), [404]);
    check('admin cookie payout 999999 WITHOUT Idempotency-Key → 422 (MQA-36)', await req('POST', '/api/admin/v1/payouts/999999', { cookie: ck, body: { action: 'reject', reason: 'qa' }, origin: ORIGIN }), [422]);
  }
  rec('payment flags untouched (no feature.payment_* rows)', psql(`select count(*) from kycore.site_settings where key like 'feature.payment_%'`) === '0', 'payment flag rows present');
  finish();
})();

function finish() {
  const f = results.filter((r) => r.ok === false).length;
  const s = results.filter((r) => r.ok === null).length;
  console.log(`\n${results.length - f - s}/${results.length} passed, ${f} failed, ${s} skipped`);
  process.exit(f ? 1 : 0);
}
