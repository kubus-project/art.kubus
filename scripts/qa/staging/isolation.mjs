// Local staging isolation: the rules every local staging build, launch and browser run
// shares, so a QA rig can never send a request to the production API.
//
// The Flutter client reads its API origin from BACKEND_BASE_URL and fails over to
// BACKEND_STANDBY_BASE_URL (lib/config/config.dart); both default to production.
// KUBUS_BACKEND_URL alone does not move the client. A staging build must therefore pin
// all three, and a staging origin must be a loopback address.
//
// Pure functions only (plus one TCP probe); the CLIs live next to this file.
import net from 'node:net';
import os from 'node:os';

/** Production API hosts. A local staging rig must never reach them. */
export const PRODUCTION_API_HOSTS = Object.freeze(['api.kubus.site', 'bapi.kubus.site']);

/** Every compile-time key that selects an API origin for the web client. */
export const BACKEND_DEFINE_KEYS = Object.freeze([
  'KUBUS_BACKEND_URL',
  'BACKEND_BASE_URL',
  'BACKEND_STANDBY_BASE_URL',
]);

/**
 * Every key a staging web build may carry. All are public (OAuth client ids, a WalletConnect
 * project id, feature flags, build metadata, the pinned origins). An unknown key fails
 * verification, so nothing secret can ride along into a staging artifact unnoticed.
 */
export const STAGING_PUBLIC_DEFINE_KEYS = Object.freeze([
  ...BACKEND_DEFINE_KEYS,
  'KUBUS_GOOGLE_CLIENT_ID', 'KUBUS_GOOGLE_WEB_CLIENT_ID', 'KUBUS_GOOGLE_IOS_CLIENT_ID',
  'KUBUS_WALLETCONNECT_PROJECT_ID', 'KUBUS_APP_VERSION', 'KUBUS_BUILD_NUMBER', 'KUBUS_BUILD_DATE',
  'KUBUS_ENABLE_WEB_SEMANTICS', 'ANALYTICS_APP_ENABLED', 'COMMUNITY_MULTI_MEDIA_ENABLED',
  'COMMUNITY_VIDEO_AUTOPLAY_ENABLED', 'COMMUNITY_VIDEO_POSTERS_ENABLED', 'SUPPORT_TICKETS_ENABLED',
]);

export class StagingConfigError extends Error {
  constructor(message) {
    super(message);
    this.name = 'StagingConfigError';
  }
}

const LOOPBACK_NAMES = new Set(['localhost', '127.0.0.1', '[::1]', '::1']);

export function isLoopbackHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  if (LOOPBACK_NAMES.has(host)) return true;
  return /^127(\.\d{1,3}){3}$/.test(host);
}

export function isProductionApiHost(hostname) {
  return PRODUCTION_API_HOSTS.includes(String(hostname || '').toLowerCase().replace(/\.$/, ''));
}

/**
 * Validates a staging origin and returns it normalised (scheme://host:port).
 * Fails closed: missing, non-HTTP, non-loopback, production, or decorated values throw.
 */
export function parseStagingOrigin(raw, label = 'staging origin') {
  const value = String(raw ?? '').trim();
  if (!value) throw new StagingConfigError(`${label} is required (for example http://127.0.0.1:53101)`);
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new StagingConfigError(`${label} must be an absolute URL: ${value}`);
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new StagingConfigError(`${label} must use http or https: ${value}`);
  }
  if (isProductionApiHost(url.hostname)) {
    throw new StagingConfigError(`${label} points at a production API host: ${url.hostname}`);
  }
  if (!isLoopbackHost(url.hostname)) {
    throw new StagingConfigError(`${label} must be a loopback address (127.0.0.1, ::1 or localhost): ${url.hostname}`);
  }
  if (url.username || url.password || (url.pathname !== '/' && url.pathname !== '') || url.search || url.hash) {
    throw new StagingConfigError(`${label} must be a bare origin (no credentials, path, query or fragment): ${value}`);
  }
  return url.origin;
}

/** Returns a copy of the build defines with every API-selecting key pinned to [origin]. */
export function pinStagingDefines(defines, origin) {
  const pinned = { ...defines };
  for (const key of BACKEND_DEFINE_KEYS) pinned[key] = origin;
  return pinned;
}

/** Lists every reason the defines would not keep the client on [origin]. Empty = isolated. */
export function verifyStagingDefines(defines, origin) {
  const problems = [];
  for (const key of BACKEND_DEFINE_KEYS) {
    const value = defines?.[key];
    if (value !== origin) problems.push(`${key} is ${value === undefined ? 'unset' : JSON.stringify(value)}, expected ${origin}`);
  }
  for (const [key, value] of Object.entries(defines || {})) {
    if (!STAGING_PUBLIC_DEFINE_KEYS.includes(key)) problems.push(`${key} is not a known public build key`);
    if (typeof value !== 'string') continue;
    for (const host of PRODUCTION_API_HOSTS) {
      if (hostPattern(host).test(value)) problems.push(`${key} references production host ${host}`);
    }
  }
  return problems;
}

function hostPattern(host) {
  // "api.kubus.site" must not match inside "bapi.kubus.site".
  return new RegExp(`(?<![a-z0-9-])${host.replaceAll('.', '\\.')}`, 'i');
}

/**
 * Counts production API endpoint references (URL forms: https://, http://, wss://, ws:// or
 * scheme-relative //host) in a compiled artifact such as main.dart.js. A bare host name in an
 * allowlist (for example the media resolver's direct-display hosts) is not an endpoint and
 * is reported by [findBareProductionHostMentions] instead.
 */
export function findProductionHostReferences(text) {
  const found = {};
  for (const host of PRODUCTION_API_HOSTS) {
    const pattern = new RegExp(`(?:(?:https?|wss?):)?//${host.replaceAll('.', '\\.')}(?![a-z0-9-]|\\.[a-z0-9])`, 'gi');
    const matches = String(text || '').match(pattern);
    if (matches?.length) found[host] = matches.length;
  }
  return found;
}

/** Bare production host mentions (no scheme), for information only. */
export function findBareProductionHostMentions(text) {
  const found = {};
  for (const host of PRODUCTION_API_HOSTS) {
    const all = String(text || '').match(new RegExp(hostPattern(host).source, 'gi'))?.length ?? 0;
    const urls = findProductionHostReferences(text)[host] ?? 0;
    if (all - urls > 0) found[host] = all - urls;
  }
  return found;
}

const READ_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

/**
 * Decides whether a browser request from a staging QA run must be aborted.
 * - Any request to a production API host is blocked, whatever the method.
 * - A write (anything but GET/HEAD/OPTIONS) to an origin outside [allowedOrigins] is
 *   blocked, so no state can change anywhere except the local staging services.
 */
export function shouldBlockRequest({ url, method }, { allowedOrigins = [] } = {}) {
  let parsed;
  try {
    parsed = new URL(url);
  } catch {
    return { block: false, reason: null };
  }
  if (parsed.protocol === 'data:' || parsed.protocol === 'blob:') return { block: false, reason: null };
  if (isProductionApiHost(parsed.hostname)) return { block: true, reason: 'production-api-host' };
  const verb = String(method || 'GET').toUpperCase();
  if (!READ_METHODS.has(verb) && !allowedOrigins.includes(parsed.origin)) {
    return { block: true, reason: 'write-outside-staging' };
  }
  return { block: false, reason: null };
}

/** A PostgreSQL URL for staging must name a loopback host and an explicit database. */
export function parseStagingDatabaseUrl(raw) {
  const value = String(raw ?? '').trim();
  if (!value) throw new StagingConfigError('staging DATABASE_URL is required');
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new StagingConfigError('staging DATABASE_URL must be a postgresql:// URL');
  }
  if (url.protocol !== 'postgresql:' && url.protocol !== 'postgres:') {
    throw new StagingConfigError('staging DATABASE_URL must be a postgresql:// URL');
  }
  if (!isLoopbackHost(url.hostname)) {
    throw new StagingConfigError(`staging DATABASE_URL must point at a loopback host, not ${url.hostname}`);
  }
  const database = decodeURIComponent(url.pathname.replace(/^\//, ''));
  if (!database) throw new StagingConfigError('staging DATABASE_URL must name its database');
  return { url: value, host: url.hostname, port: Number(url.port || 5432), database };
}

/** Machine addresses other than loopback: where an all-interfaces listener is reachable. */
export function externalAddresses(interfaces = os.networkInterfaces()) {
  const out = [];
  for (const list of Object.values(interfaces)) {
    for (const entry of list || []) {
      if (entry.internal) continue;
      if (entry.family === 'IPv6' && /^fe80:/i.test(entry.address)) continue; // link-local needs a scope id
      out.push(entry.address);
    }
  }
  return out;
}

export function canConnect(host, port, timeoutMs = 800) {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port });
    const done = (ok) => {
      socket.removeAllListeners();
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(timeoutMs, () => done(false));
    socket.once('connect', () => done(true));
    socket.once('error', () => done(false));
  });
}

/**
 * Proves a port is reachable only on loopback: connects to every external address of
 * this machine. Returns the addresses that accepted a connection (empty = local only).
 */
export async function findExposedAddresses(port, addresses = externalAddresses()) {
  const results = await Promise.all(addresses.map(async (address) => ((await canConnect(address, port)) ? address : null)));
  return results.filter(Boolean);
}
