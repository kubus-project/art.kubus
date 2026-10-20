import assert from 'node:assert/strict';
import cp from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  BACKEND_DEFINE_KEYS,
  PRODUCTION_API_HOSTS,
  externalAddresses,
  findExposedAddresses,
  findBareProductionHostMentions,
  findProductionHostReferences,
  parseStagingDatabaseUrl,
  parseStagingOrigin,
  pinStagingDefines,
  shouldBlockRequest,
  verifyStagingDefines,
} from './isolation.mjs';
import { runPreflight } from './preflight.mjs';
import { buildBackendEnv, planLaunch } from './launch_backend.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const appRoot = path.resolve(here, '..', '..', '..');
const STAGING = 'http://127.0.0.1:53101';
const WEB = 'http://127.0.0.1:58180';
const tmp = (prefix) => fs.mkdtempSync(path.join(os.tmpdir(), prefix));

test('staging origins must be bare loopback origins', () => {
  assert.equal(parseStagingOrigin('http://127.0.0.1:53101'), STAGING);
  assert.equal(parseStagingOrigin(' http://localhost:53101/ '), 'http://localhost:53101');
  assert.equal(parseStagingOrigin('http://[::1]:53101'), 'http://[::1]:53101');
  for (const bad of [undefined, '', 'https://api.kubus.site', 'https://bapi.kubus.site', 'http://192.168.1.20:53101',
    'https://staging.example.org', 'http://127.0.0.1:53101/api', 'http://u:p@127.0.0.1:53101', 'ftp://127.0.0.1', '127.0.0.1:53101']) {
    assert.throws(() => parseStagingOrigin(bad), /required|loopback|production|bare origin|http or https|absolute URL/, String(bad));
  }
});

test('the client reads exactly the define keys the staging tools pin, and only production hosts default', () => {
  const config = fs.readFileSync(path.join(appRoot, 'lib', 'config', 'config.dart'), 'utf8');
  for (const key of ['BACKEND_BASE_URL', 'BACKEND_STANDBY_BASE_URL']) {
    assert.ok(BACKEND_DEFINE_KEYS.includes(key));
    const declaration = config.match(new RegExp(`String\\.fromEnvironment\\(\\s*'${key}',[\\s\\S]*?\\);`));
    assert.ok(declaration, `lib/config/config.dart no longer reads ${key}: update scripts/qa/staging/isolation.mjs`);
    for (const [, host] of declaration[0].matchAll(/https?:\/\/([a-z0-9.-]+)/gi)) {
      assert.ok(PRODUCTION_API_HOSTS.includes(host), `${key} defaults to ${host}, which PRODUCTION_API_HOSTS does not list`);
    }
  }
});

test('defines from the public build script alone are not isolated; pinned defines are', () => {
  // Exactly what the session-4 staging build produced: only KUBUS_BACKEND_URL set.
  const raw = { KUBUS_BACKEND_URL: STAGING, COMMUNITY_MULTI_MEDIA_ENABLED: true };
  const problems = verifyStagingDefines(raw, STAGING);
  assert.ok(problems.some((p) => p.startsWith('BACKEND_BASE_URL is unset')));
  assert.ok(problems.some((p) => p.startsWith('BACKEND_STANDBY_BASE_URL is unset')));
  const pinned = pinStagingDefines(raw, STAGING);
  assert.deepEqual(verifyStagingDefines(pinned, STAGING), []);
  assert.equal(pinned.COMMUNITY_MULTI_MEDIA_ENABLED, true);
  assert.ok(verifyStagingDefines({ ...pinned, SOME_URL: 'https://bapi.kubus.site/x' }, STAGING).some((p) => /production host bapi/.test(p)));
  assert.ok(verifyStagingDefines({ ...pinned, KUBUS_SOLANA_PRIVATE_KEY: 'x' }, STAGING).some((p) => /not a known public build key/.test(p)));
});

test('artifact scan counts api and bapi endpoints separately; bare allowlist names are only noted', () => {
  assert.deepEqual(findProductionHostReferences('x "https://bapi.kubus.site" y'), { 'bapi.kubus.site': 1 });
  assert.deepEqual(findProductionHostReferences('a https://api.kubus.site/x b wss://api.kubus.site c "//api.kubus.site"'), { 'api.kubus.site': 3 });
  assert.deepEqual(findProductionHostReferences(`const u="${STAGING}"; https://app.kubus.site; https://myapi.kubus.site; https://api.kubus.site.evil`), {});
  // The media resolver's direct-display allowlist compiles to a bare host name.
  const allowlist = '{"app.kubus.site":0,"api.kubus.site":1,"art.kubus.site":2}';
  assert.deepEqual(findProductionHostReferences(allowlist), {});
  assert.deepEqual(findBareProductionHostMentions(allowlist), { 'api.kubus.site': 1 });
});

test('browser guard blocks production hosts and writes outside staging', () => {
  const allowedOrigins = [STAGING, WEB];
  const block = (url, method = 'GET') => shouldBlockRequest({ url, method }, { allowedOrigins }).block;
  assert.equal(block('https://api.kubus.site/api/community/posts'), true);
  assert.equal(block('https://BAPI.kubus.site/health'), true);
  assert.equal(block('https://api.kubus.site/x', 'POST'), true);
  assert.equal(block(`${STAGING}/api/community/posts/1/like`, 'POST'), false);
  assert.equal(block('https://tiles.example.org/style.json'), false);
  assert.equal(block('https://analytics.example.org/collect', 'POST'), true);
  assert.equal(block('https://rpc.example.org/', 'PUT'), true);
  assert.equal(block('data:image/png;base64,AAAA'), false);
});

test('staging database URLs must be loopback and name a database', () => {
  assert.equal(parseStagingDatabaseUrl('postgresql://u:p@127.0.0.1:55432/staging084').database, 'staging084');
  assert.throws(() => parseStagingDatabaseUrl('postgresql://u:p@db.example.org:5432/artkubus'), /loopback/);
  assert.throws(() => parseStagingDatabaseUrl('postgresql://u:p@127.0.0.1:55432/'), /name its database/);
  assert.throws(() => parseStagingDatabaseUrl(''), /required/);
  assert.throws(() => parseStagingDatabaseUrl('mysql://127.0.0.1/x'), /postgresql/);
});

function fakeBackend() {
  const dir = tmp('kubus-staging-be-');
  fs.mkdirSync(path.join(dir, 'src'));
  fs.writeFileSync(path.join(dir, 'src', 'server.js'), '');
  return dir;
}

test('launch plan fails closed on .env, in-repo secrets and non-loopback databases', () => {
  const backend = fakeBackend();
  const privateDir = tmp('kubus-staging-private-');
  const base = { backend, privateDir, port: 53101, webOrigin: WEB, adminOrigin: 'http://127.0.0.1:5174',
    databaseUrl: 'postgresql://u:p@127.0.0.1:55432/staging084', smtpPort: 51027 };
  assert.equal(planLaunch(base, { root: appRoot }).apiOrigin, STAGING);
  assert.throws(() => planLaunch({ ...base, privateDir: path.join(appRoot, 'output', 'x') }, { root: appRoot }), /outside/);
  assert.throws(() => planLaunch({ ...base, databaseUrl: 'postgresql://u:p@10.0.0.5:5432/artkubus' }, { root: appRoot }), /loopback/);
  assert.throws(() => planLaunch({ ...base, webOrigin: 'https://app.kubus.site' }, { root: appRoot }), /loopback/);
  fs.writeFileSync(path.join(backend, '.env'), 'DATABASE_URL=postgresql://prod');
  assert.throws(() => planLaunch(base, { root: appRoot }), /dotenv/);
});

test('backend environment comes from an allowlist plus explicit staging values', () => {
  const plan = planLaunch({ backend: fakeBackend(), privateDir: tmp('kubus-staging-private-'), port: 53101, webOrigin: WEB,
    adminOrigin: 'http://127.0.0.1:5174', databaseUrl: 'postgresql://u:p@127.0.0.1:55432/staging084', smtpPort: 51027 }, { root: appRoot });
  const env = buildBackendEnv(plan, { PATH: '/bin', DATABASE_URL: 'postgresql://prod', REDIS_URL: 'redis://prod', ORBITDB_SYNC_MODE: 'on', AWS_SECRET_ACCESS_KEY: 'x' });
  assert.equal(env.PATH, '/bin');
  assert.equal(env.DATABASE_URL, 'postgresql://u:p@127.0.0.1:55432/staging084');
  assert.equal(env.LISTEN_HOST, '127.0.0.1');
  assert.equal(env.ORBITDB_SYNC_MODE, 'off');
  assert.equal(env.REDIS_URL, undefined);
  assert.equal(env.AWS_SECRET_ACCESS_KEY, undefined);
  assert.equal(env.HTTP_BASE_URL, STAGING);
  for (const value of Object.values(env)) assert.deepEqual(findProductionHostReferences(value), {});
  // The admin status monitor falls back to production targets for an empty or invalid list.
  const targets = JSON.parse(env.ADMIN_MONITOR_TARGETS);
  assert.ok(targets.length > 0);
  for (const t of targets) assert.ok(t.id && /^https?:\/\//.test(t.url) && parseStagingOrigin(new URL(t.url).origin), t.url);
  assert.equal(env.PUBLIC_API_URL, STAGING);
  assert.equal(env.SEO_PUBLIC_BASE_URL, WEB);
  assert.ok(Number(env.AUTH_RATE_LIMIT_MAX_REQUESTS) >= 1000, 'sign-in limiter raised for QA');
});

function listen(host) {
  return new Promise((resolve) => {
    const server = http.createServer((_, res) => res.end('ok'));
    server.listen(0, host, () => resolve(server));
  });
}

test('exposure probe: a loopback listener is local only', async () => {
  const server = await listen('127.0.0.1');
  try {
    assert.deepEqual(await findExposedAddresses(server.address().port), []);
  } finally {
    server.close();
  }
});

test('exposure probe: an all-interfaces listener is reported', { skip: externalAddresses().length === 0 && 'no external interface' }, async () => {
  const server = await listen('0.0.0.0');
  try {
    const exposed = await findExposedAddresses(server.address().port, externalAddresses().filter((a) => !a.includes(':')));
    assert.ok(exposed.length > 0);
  } finally {
    server.close();
  }
});

function fakeArtifact(mainJs, defines) {
  const root = tmp('kubus-staging-web-');
  fs.mkdirSync(path.join(root, 'build', 'web'), { recursive: true });
  fs.mkdirSync(path.join(root, '.dart_tool'));
  fs.writeFileSync(path.join(root, 'build', 'web', 'main.dart.js'), mainJs);
  fs.writeFileSync(path.join(root, '.dart_tool', 'public-build-defines.json'), JSON.stringify(defines));
  return path.join(root, 'build', 'web');
}

const okFetch = async (url) => ({ status: 200, json: async () => (url.endsWith('/health') ? { status: 'ok' } : {}) });
const noExposure = async () => [];

test('preflight passes only a pinned, production-free artifact with local-only services', async () => {
  const pinned = pinStagingDefines({ KUBUS_BACKEND_URL: STAGING }, STAGING);
  const good = await runPreflight({ api: STAGING, web: WEB, webRoot: fakeArtifact(`x="${STAGING}"`, pinned) }, { fetchImpl: okFetch, exposure: noExposure });
  assert.equal(good.ok, true, JSON.stringify(good.checks));

  const unpinned = await runPreflight({ api: STAGING, web: WEB, webRoot: fakeArtifact(`x="${STAGING}"`, { KUBUS_BACKEND_URL: STAGING }) }, { fetchImpl: okFetch, exposure: noExposure });
  assert.equal(unpinned.ok, false);

  const prodArtifact = await runPreflight({ api: STAGING, web: WEB, webRoot: fakeArtifact(`x="${STAGING}";y="https://bapi.kubus.site"`, pinned) }, { fetchImpl: okFetch, exposure: noExposure });
  assert.equal(prodArtifact.checks.find((c) => c.name.startsWith('artifact has no production')).ok, false);

  const exposed = await runPreflight({ api: STAGING, web: WEB, webRoot: fakeArtifact(`x="${STAGING}"`, pinned) }, { fetchImpl: okFetch, exposure: async () => ['192.168.1.20'] });
  assert.equal(exposed.ok, false);

  const down = await runPreflight({ api: STAGING, web: WEB, webRoot: fakeArtifact(`x="${STAGING}"`, pinned) }, { fetchImpl: async () => { throw new Error('ECONNREFUSED'); }, exposure: noExposure });
  assert.equal(down.ok, false);

  await assert.rejects(runPreflight({ api: 'https://api.kubus.site', web: WEB, webRoot: '.' }), /production/);
  await assert.rejects(runPreflight({ web: WEB, webRoot: '.' }), /required/);
});

test('staging build refuses to run without a staging origin and pins all three keys with one', () => {
  const root = tmp('kubus-staging-build-');
  fs.mkdirSync(path.join(root, 'scripts', 'qa', 'staging'), { recursive: true });
  fs.mkdirSync(path.join(root, 'ios', 'Flutter'), { recursive: true });
  fs.mkdirSync(path.join(root, 'web'));
  fs.copyFileSync(path.join(appRoot, 'web', 'index.html'), path.join(root, 'web', 'index.html'));
  fs.copyFileSync(path.join(appRoot, 'scripts', 'prepare_public_build_config.mjs'), path.join(root, 'scripts', 'prepare_public_build_config.mjs'));
  for (const f of ['build_web.mjs', 'isolation.mjs', 'preflight.mjs']) fs.copyFileSync(path.join(here, f), path.join(root, 'scripts', 'qa', 'staging', f));
  const env = { ...process.env, KUBUS_GOOGLE_CLIENT_ID: 'public-client', KUBUS_GOOGLE_WEB_CLIENT_ID: 'public-web-client',
    KUBUS_GOOGLE_IOS_CLIENT_ID: 'public-ios.apps.googleusercontent.com' };
  for (const key of ['KUBUS_STAGING_API_ORIGIN', 'KUBUS_BACKEND_URL', 'KUBUS_APP_VERSION', 'KUBUS_BUILD_NUMBER', 'KUBUS_BUILD_DATE', 'KUBUS_REQUIRE_STAGING_BACKEND']) delete env[key];
  const script = path.join(root, 'scripts', 'qa', 'staging', 'build_web.mjs');
  const runBuild = (extra) => cp.spawnSync(process.execPath, [script, '--skip-flutter'], { cwd: root, env: { ...env, ...extra }, encoding: 'utf8' });

  const missing = runBuild({});
  assert.equal(missing.status, 2, missing.stderr);
  assert.match(missing.stderr, /KUBUS_STAGING_API_ORIGIN is required/);
  assert.equal(fs.existsSync(path.join(root, '.dart_tool', 'public-build-defines.json')), false);

  assert.equal(runBuild({ KUBUS_STAGING_API_ORIGIN: 'https://api.kubus.site' }).status, 2);

  const ok = runBuild({ KUBUS_STAGING_API_ORIGIN: STAGING });
  assert.equal(ok.status, 0, ok.stderr);
  const defines = JSON.parse(fs.readFileSync(path.join(root, '.dart_tool', 'public-build-defines.json'), 'utf8'));
  for (const key of BACKEND_DEFINE_KEYS) assert.equal(defines[key], STAGING, key);
});
