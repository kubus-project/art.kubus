#!/usr/bin/env node
// Staging preflight: run before any browser opens against local staging. Exits non-zero
// unless every effective endpoint is the isolated local staging stack.
//
//   node scripts/qa/staging/preflight.mjs --api http://127.0.0.1:53101 \
//     --web http://127.0.0.1:58180 --web-root build/web \
//     [--defines .dart_tool/public-build-defines.json] [--artifact-only]
//
// Checks: both origins are loopback and not production; the build defines pin every
// API-selecting key to the API origin; the compiled main.dart.js names no production API
// host; the backend answers /health; the backend and web ports refuse connections on
// every non-loopback address of this machine.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  StagingConfigError,
  findExposedAddresses,
  findBareProductionHostMentions,
  findProductionHostReferences,
  parseStagingOrigin,
  verifyStagingDefines,
} from './isolation.mjs';

export function parseArgs(argv) {
  const opts = { artifactOnly: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) throw new StagingConfigError(`${arg} needs a value`);
      i += 1;
      return value;
    };
    if (arg === '--api') opts.api = next();
    else if (arg === '--web') opts.web = next();
    else if (arg === '--web-root') opts.webRoot = next();
    else if (arg === '--defines') opts.defines = next();
    else if (arg === '--artifact-only') opts.artifactOnly = true;
    else throw new StagingConfigError(`unknown argument ${arg}`);
  }
  return opts;
}

export async function runPreflight(opts, { fetchImpl = fetch, exposure = findExposedAddresses } = {}) {
  const checks = [];
  const record = (name, ok, detail) => checks.push({ name, ok, detail });

  const api = parseStagingOrigin(opts.api, '--api');
  const web = opts.artifactOnly ? null : parseStagingOrigin(opts.web, '--web');
  if (!opts.webRoot) throw new StagingConfigError('--web-root is required');
  const webRoot = path.resolve(opts.webRoot);

  const definesPath = opts.defines
    ? path.resolve(opts.defines)
    : path.resolve(webRoot, '..', '..', '.dart_tool', 'public-build-defines.json');
  if (!fs.existsSync(definesPath)) {
    record('build defines pinned', false, `missing ${definesPath}`);
  } else {
    const problems = verifyStagingDefines(JSON.parse(fs.readFileSync(definesPath, 'utf8')), api);
    record('build defines pinned', problems.length === 0, problems.length ? problems.join('; ') : definesPath);
  }

  const mainJs = path.join(webRoot, 'main.dart.js');
  if (!fs.existsSync(mainJs)) {
    record('artifact has no production API endpoint', false, `missing ${mainJs}`);
  } else {
    const text = fs.readFileSync(mainJs, 'utf8');
    const found = findProductionHostReferences(text);
    const pinned = text.includes(api);
    record('artifact has no production API endpoint', Object.keys(found).length === 0, Object.keys(found).length ? JSON.stringify(found) : 'none');
    record('artifact embeds the staging API origin', pinned, pinned ? api : `${api} not found in main.dart.js`);
    const bare = findBareProductionHostMentions(text);
    if (Object.keys(bare).length) checks.push({ name: 'note: bare production host names (allowlists, not endpoints)', ok: true, detail: JSON.stringify(bare) });
  }

  if (!opts.artifactOnly) {
    try {
      const res = await fetchImpl(`${api}/health`, { signal: AbortSignal.timeout(5000) });
      const body = await res.json().catch(() => ({}));
      record('backend /health', res.status === 200 && body.status === 'ok', `${res.status} ${body.status ?? ''} ${body.version ?? ''}`.trim());
    } catch (error) {
      record('backend /health', false, error.message);
    }
    try {
      const res = await fetchImpl(`${web}/`, { signal: AbortSignal.timeout(5000) });
      record('web origin serves the app', res.status === 200, String(res.status));
    } catch (error) {
      record('web origin serves the app', false, error.message);
    }
    for (const [label, origin] of [['backend', api], ['web', web]]) {
      const port = Number(new URL(origin).port || (origin.startsWith('https:') ? 443 : 80));
      const exposed = await exposure(port);
      record(`${label} port ${port} listens on loopback only`, exposed.length === 0, exposed.length ? `reachable on ${exposed.join(', ')}` : 'local only');
    }
  }

  return { ok: checks.every((c) => c.ok), api, web, checks };
}

async function main() {
  let report;
  try {
    report = await runPreflight(parseArgs(process.argv.slice(2)));
  } catch (error) {
    console.error(`staging preflight: ${error.message}`);
    process.exit(2);
  }
  for (const c of report.checks) console.log(`${c.ok ? 'PASS' : 'FAIL'}  ${c.name}: ${c.detail}`);
  console.log(report.ok ? 'staging preflight PASSED' : 'staging preflight FAILED');
  process.exit(report.ok ? 0 : 1);
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) main();
