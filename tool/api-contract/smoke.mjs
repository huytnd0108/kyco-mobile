#!/usr/bin/env node
// Mobile ↔ backend contract smoke — exercises the /api/v1 surface EXACTLY as the
// Flutter client calls it (Bearer, same paths/bodies as lib/core/api/*.dart),
// against a running kyco backend. Used to QA the web-API-only migration batch by
// batch; failures go to kyco-wt/MOBILE-QA-FEEDBACK.md.
//
//   API_BASE=http://127.0.0.1:4142/api/v1 node tool/api-contract/smoke.mjs [--only=addresses,provider]
//
// Accounts (QA DB only): CUSTOMER_EMAIL/PASSWORD, PROVIDER_EMAIL/PASSWORD, ADMIN_EMAIL/PASSWORD.
// Exit 1 when any check fails. Never point this at production: it creates data.

const BASE = process.env.API_BASE || 'http://127.0.0.1:4142/api/v1';
if (/kyco\.vn/.test(BASE) && !process.env.ALLOW_REMOTE) {
  console.error('refusing to run the mutating smoke against kyco.vn (set ALLOW_REMOTE=1 to override)');
  process.exit(2);
}
const ACC = {
  customer: [process.env.CUSTOMER_EMAIL || 'demo@demo.local', process.env.CUSTOMER_PASSWORD || 'demo12345'],
  provider: [process.env.PROVIDER_EMAIL || 'provider@qa.local', process.env.PROVIDER_PASSWORD || 'ProvQa12345!'],
  admin: [process.env.ADMIN_EMAIL || 'admin@qa.local', process.env.ADMIN_PASSWORD || 'Admin12345qa'],
};
const only = (process.argv.find((a) => a.startsWith('--only=')) || '').slice(7).split(',').filter(Boolean);
const want = (g) => only.length === 0 || only.includes(g);

const results = [];
function record(group, name, ok, detail) {
  results.push({ group, name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  [${group}] ${name}${ok ? '' : `  — ${detail}`}`);
}

// SMOKE_PACE_MS spaces requests out (the edge limiter counts Bearer calls as
// anonymous: 30/min/IP — see MOBILE-QA-FEEDBACK MQA-1). 0 = full speed.
const PACE = Number(process.env.SMOKE_PACE_MS || 0);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function call(method, path, { token, body, headers = {} } = {}) {
  if (PACE) await sleep(PACE);
  const h = { Accept: 'application/json', 'User-Agent': 'kyco-mobile-smoke/1', ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  if (body !== undefined) h['Content-Type'] = 'application/json';
  const res = await fetch(BASE + path, { method, headers: h, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* non-JSON */ }
  return { status: res.status, json, text: text.slice(0, 300) };
}
// Mirrors api_client.dart: unwraps {ok,data} envelopes.
const data = (r) => (r.json && typeof r.json === 'object' && 'data' in r.json ? r.json.data : r.json);

async function expect(group, name, method, path, opts, statuses, check) {
  try {
    const r = await call(method, path, opts);
    const okStatus = (Array.isArray(statuses) ? statuses : [statuses]).includes(r.status);
    let why = okStatus ? null : `HTTP ${r.status} ${r.text}`;
    if (!why && check) { const c = check(data(r), r); if (c !== true) why = `shape: ${c}`; }
    record(group, `${method} ${path} ${name}`.trim(), !why, why);
    return r;
  } catch (e) {
    record(group, `${method} ${path} ${name}`.trim(), false, String(e));
    return { status: 0, json: null };
  }
}

async function login(role) {
  const [email, password] = ACC[role];
  const r = await call('POST', '/auth/login', { body: { email, password } });
  const d = data(r);
  if (r.status !== 200 || !d?.accessToken) { record('auth', `login ${role}`, false, `HTTP ${r.status} ${r.text}`); return null; }
  const roleOk = role === 'customer' ? d.user?.role === 'customer' : d.user?.role === role;
  record('auth', `login ${role} → role ${d.user?.role}`, roleOk, `expected ${role}`);
  return d;
}

const isList = (d) => Array.isArray(d) || Array.isArray(d?.items) || 'expected array or {items}';

async function main() {
  console.log(`smoke against ${BASE}`);
  const health = await call('GET', '/services');
  if (health.status === 503) { console.error('api_mobile_v1_enabled is OFF (503) — enable it first'); process.exit(2); }

  const cust = await login('customer');
  const prov = await login('provider');
  const admin = await login('admin');
  const C = cust?.accessToken, P = prov?.accessToken;

  if (want('auth') && cust) {
    const rf = await expect('auth', 'refresh rotates', 'POST', '/auth/refresh', { body: { refreshToken: cust.refreshToken } }, 200, (d) => (d?.accessToken && d?.refreshToken && d.refreshToken !== cust.refreshToken) || 'no rotated pair');
    await expect('auth', 'reused refresh rejected', 'POST', '/auth/refresh', { body: { refreshToken: cust.refreshToken } }, 401);
    await expect('auth', 'no token → 401', 'GET', '/me', {}, 401);
    if (data(rf)?.accessToken) await expect('auth', 'me with refreshed token', 'GET', '/me', { token: data(rf).accessToken }, 200);
  }

  if (want('public')) {
    await expect('public', '', 'GET', '/home', {}, 200);
    const svc = await expect('public', '', 'GET', '/services?page=1&limit=10', {}, 200, isList);
    const items = data(svc)?.items ?? data(svc);
    const sid = Array.isArray(items) && items[0]?.id;
    await expect('public', '', 'GET', '/catalog/tree', {}, 200);
    await expect('public', '', 'GET', '/locations/tree', {}, 200);
    await expect('public', '', 'GET', '/search?q=v%E1%BB%87&limit=5', {}, 200);
    await expect('public', '', 'GET', '/plans', {}, 200);
    if (sid) {
      await expect('public', '', 'GET', `/services/${sid}`, {}, 200, (d) => (d?.id === sid) || 'id mismatch');
      await expect('public', '', 'GET', `/services/${sid}/related`, {}, 200);
      await expect('public', '', 'GET', `/services/${sid}/reviews`, {}, 200);
      if (C) await expect('customer', '', 'GET', `/checkout/${sid}`, { token: C }, 200);
    }
    await expect('public', '', 'GET', '/providers/1/public', {}, [200, 404]);
  }

  if (want('customer') && C) {
    await expect('customer', '', 'GET', '/me', { token: C }, 200, (d) => (d?.id || d?.user?.id) ? true : 'no id');
    await expect('customer', '', 'GET', '/bookings', { token: C }, 200, isList);
    await expect('customer', '', 'GET', '/subscriptions', { token: C }, 200);
    await expect('customer', '', 'GET', '/notifications?limit=20', { token: C }, 200);
    await expect('customer', '', 'GET', '/dashboard', { token: C }, 200);
    await expect('customer', 'customer forbidden on provider surface', 'GET', '/provider/workspace', { token: C }, [401, 403]);
  }

  if (want('addresses') && C) {
    const g = 'addresses';
    await expect(g, 'list', 'GET', '/addresses', { token: C }, 200, isList);
    const body = { label: 'Nhà QA', line: '12 Lê Lợi', district: 'Quận 1', ward: 'Bến Nghé', city: 'Hồ Chí Minh', isDefault: true };
    const cr = await expect(g, 'create', 'POST', '/addresses', { token: C, body }, 201, (d) => (d?.id ? true : 'no id'));
    const id = data(cr)?.id;
    await expect(g, 'create invalid (empty line) → 4xx', 'POST', '/addresses', { token: C, body: { ...body, line: '' } }, [400, 422]);
    if (id) {
      await expect(g, 'get own', 'GET', `/addresses/${id}`, { token: C }, 200, (d) => (d?.line === body.line) || `line=${d?.line}`);
      await expect(g, 'patch own', 'PATCH', `/addresses/${id}`, { token: C, body: { label: 'Công ty QA' } }, 200);
      await expect(g, 'patch persisted + omitted fields kept (MQA-2)', 'GET', `/addresses/${id}`, { token: C }, 200, (d) =>
        (d?.label === 'Công ty QA' && d?.line === body.line && d?.district === body.district && d?.ward === body.ward && d?.city === body.city)
        || `label=${d?.label} line=${d?.line} district=${d?.district} ward=${d?.ward} city=${d?.city}`);
      if (P) {
        await expect(g, 'IDOR: other user GET → 404', 'GET', `/addresses/${id}`, { token: P }, [403, 404]);
        await expect(g, 'IDOR: other user PATCH → 404', 'PATCH', `/addresses/${id}`, { token: P, body: { label: 'x' } }, [403, 404]);
        await expect(g, 'IDOR: other user DELETE → 404', 'DELETE', `/addresses/${id}`, { token: P }, [403, 404]);
      }
      await expect(g, 'cookie-less Bearer mutation needs no CSRF', 'PATCH', `/addresses/${id}`, { token: C, body: { label: 'Nhà QA 2' }, headers: { Origin: 'https://evil.example' } }, 200);
      await expect(g, 'delete own', 'DELETE', `/addresses/${id}`, { token: C }, [200, 204]);
      await expect(g, 'deleted → 404', 'GET', `/addresses/${id}`, { token: C }, 404);
    }
  }

  if (want('provider') && P) {
    const g = 'provider';
    for (const p of ['/provider/workspace', '/provider/dashboard', '/provider/jobs?limit=20', '/provider/jobs/pool', '/provider/wallet',
      '/provider/wallet/transactions?limit=20', '/provider/payouts?limit=20', '/provider/bonuses', '/provider/goals', '/provider/leaderboard',
      '/provider/availability', '/provider/support', '/provider/fines', '/provider/referrals', '/provider/cancellations', '/auth/step-up']) {
      await expect(g, '', 'GET', p, { token: P }, 200);
    }
    const pool = data(await call('GET', '/provider/jobs/pool', { token: P }));
    const leaked = JSON.stringify(pool ?? {}).includes('dispatchCandidates');
    record(g, 'pool hides dispatchCandidates (review Z2)', !leaked, 'dispatchCandidates present in response');
  }

  if (want('admin') && admin) {
    await expect('admin', 'admin Bearer on /v1/me', 'GET', '/me', { token: admin.accessToken }, 200);
  }

  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  if (process.env.SMOKE_JSON) {
    const fs = await import('node:fs');
    fs.writeFileSync(process.env.SMOKE_JSON, JSON.stringify({ base: BASE, at: new Date().toISOString(), results }, null, 2));
  }
  process.exit(failed.length ? 1 : 0);
}
main();
