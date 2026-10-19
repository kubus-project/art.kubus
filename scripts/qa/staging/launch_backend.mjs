#!/usr/bin/env node
// Starts an art.kubus-backend checkout as an isolated local staging API.
//
//   node scripts/qa/staging/launch_backend.mjs --backend <backend checkout> \
//     --private <dir outside this repo> --database-url postgresql://u:p@127.0.0.1:55432/staging084 \
//     [--port 53101] [--web-origin http://127.0.0.1:58180] [--admin-origin http://127.0.0.1:5174] \
//     [--smtp-port 51027]
//
// Fails closed: the database must be on loopback, the backend tree must not carry a .env
// file (dotenv would load it), the private directory (secrets, uploads, log) must be
// outside this repository, the child environment is built from an allowlist (nothing
// else leaks in from the parent shell), and the server must bind 127.0.0.1 only
// (LISTEN_HOST, art.kubus-backend #100). If the port answers on any external address
// after startup, the backend is stopped and the launch fails.
import { randomBytes } from 'node:crypto';
import cp from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { StagingConfigError, findExposedAddresses, parseStagingDatabaseUrl, parseStagingOrigin } from './isolation.mjs';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..', '..');

/** Parent variables a Node process needs to run on Windows, macOS and Linux. Nothing else is inherited. */
export const INHERITED_ENV_KEYS = Object.freeze([
  'PATH', 'Path', 'PATHEXT', 'SystemRoot', 'SYSTEMROOT', 'windir', 'ComSpec', 'TEMP', 'TMP', 'TMPDIR',
  'HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'NUMBER_OF_PROCESSORS', 'OS', 'PROCESSOR_ARCHITECTURE',
  'LANG', 'TZ',
]);

export function parseArgs(argv) {
  const opts = {
    port: 53101,
    webOrigin: 'http://127.0.0.1:58180',
    adminOrigin: 'http://127.0.0.1:5174',
    smtpPort: 51027,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const value = argv[i + 1];
    if (value === undefined || value.startsWith('--')) throw new StagingConfigError(`${arg} needs a value`);
    i += 1;
    if (arg === '--backend') opts.backend = value;
    else if (arg === '--private') opts.privateDir = value;
    else if (arg === '--database-url') opts.databaseUrl = value;
    else if (arg === '--port') opts.port = Number(value);
    else if (arg === '--web-origin') opts.webOrigin = value;
    else if (arg === '--admin-origin') opts.adminOrigin = value;
    else if (arg === '--smtp-port') opts.smtpPort = Number(value);
    else throw new StagingConfigError(`unknown argument ${arg}`);
  }
  return opts;
}

function isInside(child, parent) {
  const rel = path.relative(parent, child);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

/** Validates the launch options. Returns the normalised plan or throws StagingConfigError. */
export function planLaunch(opts, { root = repoRoot } = {}) {
  if (!opts.backend) throw new StagingConfigError('--backend is required');
  if (!opts.privateDir) throw new StagingConfigError('--private is required');
  const backend = path.resolve(opts.backend);
  if (!fs.existsSync(path.join(backend, 'src', 'server.js'))) {
    throw new StagingConfigError(`--backend is not an art.kubus-backend checkout: ${backend}`);
  }
  if (fs.existsSync(path.join(backend, '.env'))) {
    throw new StagingConfigError(`${path.join(backend, '.env')} exists; dotenv would load it into staging. Move it away first.`);
  }
  const privateDir = path.resolve(opts.privateDir);
  if (isInside(privateDir, path.resolve(root)) || isInside(privateDir, backend)) {
    throw new StagingConfigError('--private must be outside the app repository and the backend checkout');
  }
  if (!Number.isInteger(opts.port) || opts.port < 1024 || opts.port > 65535) {
    throw new StagingConfigError(`--port must be an unprivileged TCP port: ${opts.port}`);
  }
  const database = parseStagingDatabaseUrl(opts.databaseUrl);
  const apiOrigin = parseStagingOrigin(`http://127.0.0.1:${opts.port}`, 'API origin');
  const webOrigin = parseStagingOrigin(opts.webOrigin, '--web-origin');
  const adminOrigin = parseStagingOrigin(opts.adminOrigin, '--admin-origin');
  return { backend, privateDir, port: opts.port, database, apiOrigin, webOrigin, adminOrigin, smtpPort: opts.smtpPort };
}

function readOrCreateSecret(file) {
  if (!fs.existsSync(file)) fs.writeFileSync(file, randomBytes(48).toString('hex'), { mode: 0o600 });
  return fs.readFileSync(file, 'utf8').trim();
}

/** The complete child environment: allowlisted parent keys plus explicit staging values. */
export function buildBackendEnv(plan, parentEnv = process.env, secrets = { jwt: 'test', admin: 'test' }) {
  const env = {};
  for (const key of INHERITED_ENV_KEYS) if (parentEnv[key] !== undefined) env[key] = parentEnv[key];
  return {
    ...env,
    NODE_ENV: 'development',
    PORT: String(plan.port),
    LISTEN_HOST: '127.0.0.1',
    DATABASE_URL: plan.database.url,
    JWT_SECRET: secrets.jwt,
    ADMIN_SESSION_SECRET: secrets.admin,
    ADMIN_SESSION_STORE: 'memory',
    ADMIN_WHITELIST_PATH: path.join(plan.privateDir, 'admin-whitelist.json'),
    CORS_ORIGIN: [plan.webOrigin, plan.adminOrigin].join(','),
    APP_BASE_URL: plan.webOrigin,
    DEFAULT_STORAGE_PROVIDER: 'http',
    HTTP_BASE_URL: plan.apiOrigin,
    HTTP_STORAGE_PATH: path.join(plan.privateDir, 'uploads'),
    ORBITDB_AUTO_INIT: 'false',
    ORBITDB_SYNC_MODE: 'off',
    CACHE_ENABLED: 'false',
    ENABLE_EMAIL_AUTH: 'true',
    AUTH_EMAIL_IN_MEMORY_FALLBACK_ENABLED: 'false',
    SMTP_HOST: '127.0.0.1',
    SMTP_PORT: String(plan.smtpPort),
    SMTP_USER: 'isolated',
    SMTP_PASS: 'isolated',
    SMTP_FROM: 'qa@staging.local',
    SMTP_SECURE: 'false',
    SMTP_VERIFY_ON_INIT: 'false',
    EMAIL_OCTOPUS_WAITLIST_LIST_ID: 'isolated-unused',
    EMAIL_OCTOPUS_NEWSLETTER_LIST_ID: 'isolated-unused',
    AUTH_RATE_LIMIT: '200000',
    ANON_RATE_LIMIT: '200000',
    FEATURE_ENABLE_INSTITUTION_CLAIMS: 'true',
  };
}

async function waitForHealth(origin, timeoutMs = 90000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(`${origin}/health`, { signal: AbortSignal.timeout(3000) });
      if (res.status === 200) return true;
    } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 1000));
  }
  return false;
}

async function main() {
  let plan;
  try {
    plan = planLaunch(parseArgs(process.argv.slice(2)));
  } catch (error) {
    console.error(`staging launch: ${error.message}`);
    process.exit(2);
  }
  fs.mkdirSync(path.join(plan.privateDir, 'uploads'), { recursive: true });
  const whitelist = path.join(plan.privateDir, 'admin-whitelist.json');
  if (!fs.existsSync(whitelist)) {
    console.error(`staging launch: ${whitelist} is missing (synthetic admin accounts only)`);
    process.exit(2);
  }
  const env = buildBackendEnv(plan, process.env, {
    jwt: readOrCreateSecret(path.join(plan.privateDir, 'jwt-secret')),
    admin: readOrCreateSecret(path.join(plan.privateDir, 'admin-session-secret')),
  });
  const logFile = path.join(plan.privateDir, `backend-${plan.port}.log`);
  const log = fs.openSync(logFile, 'a');
  const child = cp.spawn(process.execPath, ['src/server.js'], {
    cwd: plan.backend, env, stdio: ['ignore', log, log], windowsHide: true, detached: true,
  });
  child.unref();
  console.log(`staging backend pid ${child.pid}: ${plan.backend} -> ${plan.apiOrigin} (db ${plan.database.database}), log ${logFile}`);

  if (!(await waitForHealth(plan.apiOrigin))) {
    try { process.kill(child.pid); } catch { /* already gone */ }
    console.error('staging launch: /health did not answer within 90 s; backend stopped. See the log.');
    process.exit(1);
  }
  const exposed = await findExposedAddresses(plan.port);
  if (exposed.length) {
    try { process.kill(child.pid); } catch { /* already gone */ }
    console.error(`staging launch: port ${plan.port} answered on ${exposed.join(', ')}; backend stopped. ` +
      'The checkout must support LISTEN_HOST (art.kubus-backend #100).');
    process.exit(1);
  }
  console.log(`staging backend healthy and bound to loopback only (pid ${child.pid})`);
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) main();
