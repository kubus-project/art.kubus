#!/usr/bin/env node
// Reproducible web cold/warm start baseline for two or more release builds.
//
// Each build must be a `flutter build web --release` output built with
// `--dart-define=KUBUS_BOOT_TRACE=true`, so StartupTrace prints `[BOOT]` marks.
// Builds are interleaved run by run so drift affects them equally.
//
//   QA_BUILDS="base=C:/kubus-build/084-base/build/web,candidate=C:/kubus-build/084-perf/build/web"
//   QA_BROWSERS=chromium,firefox  QA_VIEWPORTS=390x844,1440x900  QA_RUNS=5
//   QA_SCENARIOS=anonymous,returning-wallet  QA_ENTRIES=/map  QA_OUT=C:/.../startup-baseline
//   node scripts/qa/web_startup_baseline.mjs
//
// Raw results hold URLs with query strings stripped of nothing but tokens:
// the anonymous and returning-wallet scenarios carry no session or secret.
import { createServer } from 'node:http';
import { createReadStream, existsSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { extname, join, resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';
import { chromium, firefox } from 'playwright';

const env = (name, fallback) => (process.env[name] ?? fallback).trim();
const list = (name, fallback) => env(name, fallback).split(',').map((value) => value.trim()).filter(Boolean);

const BUILDS = list('QA_BUILDS', '').map((pair) => {
  const [label, dir] = pair.split('=');
  return { label, dir: resolve(dir) };
});
const BROWSERS = list('QA_BROWSERS', 'chromium,firefox');
const VIEWPORTS = list('QA_VIEWPORTS', '390x844,1440x900').map((value) => {
  const [width, height] = value.split('x').map(Number);
  return { width, height, label: value };
});
const RUNS = Number(env('QA_RUNS', '5'));
const SCENARIOS = list('QA_SCENARIOS', 'anonymous,returning-wallet');
const ENTRIES = list('QA_ENTRIES', '/map');
const OUT = resolve(env('QA_OUT', 'output/startup-baseline'));
const SETTLE_MS = Number(env('QA_SETTLE_MS', '4000'));
const WARMUP_GRACE_MS = Number(env('QA_WARMUP_GRACE_MS', '8000'));
// Empty string disables the origin rewrite (for a local or staging backend).
const API_ORIGIN = env('QA_API_ORIGIN', 'https://app.kubus.site');
const TIMEOUT_MS = Number(env('QA_TIMEOUT_MS', '60000'));
// A syntactically valid, unfunded public key: the returning-wallet scenario
// only needs a remembered address, never a key.
const RETURNING_WALLET = env('QA_RETURNING_WALLET', 'Ee8dBVCwEvaHkkhJ4H6dPv7LDsTKj4FtuYrNRtSmYgDA');

function checkBuilds() {
  if (BUILDS.length === 0) throw new Error('QA_BUILDS is required');
  for (const build of BUILDS) {
    if (!existsSync(join(build.dir, 'main.dart.js'))) throw new Error(`${build.dir} is not a web build`);
  }
}

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
  '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2', '.pbf': 'application/x-protobuf',
  '.txt': 'text/plain', '.xml': 'application/xml', '.webmanifest': 'application/manifest+json',
};

function serve(root) {
  return new Promise((done) => {
    const server = createServer((request, response) => {
      const pathname = decodeURIComponent(new URL(request.url, 'http://local').pathname);
      let file = resolve(root, `.${pathname}`);
      // path.resolve keeps Windows separators, so compare against root + sep.
      if (file !== root && !file.startsWith(root + sep)) file = join(root, 'index.html');
      if (!existsSync(file) || statSync(file).isDirectory()) file = join(root, 'index.html');
      response.writeHead(200, {
        'Content-Type': MIME[extname(file)] || 'application/octet-stream',
        'Cache-Control': 'public, max-age=600',
      });
      createReadStream(file).pipe(response);
    });
    server.listen(0, '127.0.0.1', () => done(server));
  });
}

export function classify(url) {
  const { hostname, pathname } = new URL(url);
  if (hostname === '127.0.0.1') return 'app-static';
  if (/solana|helius|rpcpool|quiknode|triton/.test(hostname)) return 'solana-rpc';
  if (/ipfs|dweb\.link|pinata|w3s\.link|nftstorage|arweave/.test(hostname)) return 'ipfs';
  if (/api\.kubus\.site$/.test(hostname)) return pathname.startsWith('/uploads/') ? 'backend-media' : 'backend-api';
  if (/cartocdn|basemaps|maptiler|tiles|openfreemap/.test(hostname)) return 'map-tiles';
  if (/fonts\.(gstatic|googleapis)\.com/.test(hostname)) return 'google-fonts';
  if (/accounts\.google\.com|gstatic\.com|googleapis\.com/.test(hostname)) return 'google-identity';
  if (/gstatic|unpkg|jsdelivr|cdnjs/.test(hostname)) return 'cdn';
  return `other:${hostname}`;
}

function rpcMethods(body) {
  if (!body) return [];
  try {
    const parsed = JSON.parse(body);
    return (Array.isArray(parsed) ? parsed : [parsed]).map((call) => call?.method).filter(Boolean);
  } catch {
    return ['(unparsed)'];
  }
}

const median = (values) => {
  const sorted = values.filter((value) => Number.isFinite(value)).sort((a, b) => a - b);
  if (sorted.length === 0) return null;
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : Math.round((sorted[middle - 1] + sorted[middle]) / 2);
};

async function measureLoad(page, url, startedAt, state) {
  state.requests.length = 0;
  state.marks.length = 0;
  state.blockedWrites.length = 0;
  const milestones = {};
  const navigationStart = Date.now();
  await page.goto(url, { waitUntil: 'commit', timeout: TIMEOUT_MS });
  const deadline = navigationStart + TIMEOUT_MS;
  const since = () => Date.now() - navigationStart;
  // Poll DOM milestones: the map canvas appears when MapLibre mounts.
  while (Date.now() < deadline) {
    if (milestones.mapCanvas === undefined) {
      const hasCanvas = await page.evaluate(() => Boolean(document.querySelector('canvas.maplibregl-canvas'))).catch(() => false);
      if (hasCanvas) milestones.mapCanvas = since();
    }
    if (milestones.mapCanvas !== undefined && milestones.mapTile === undefined) {
      const tile = state.requests.find((entry) => entry.kind === 'map-tiles' && entry.finishedAt && entry.status < 400);
      if (tile) milestones.mapTile = tile.finishedAt - navigationStart;
    }
    if (milestones.mapTile !== undefined && milestones.mapInteractive === undefined) {
      // First moment the main thread answers a frame request once the map
      // has content: the earliest point a pan or tap can be handled.
      await page.evaluate(() => new Promise((done) => requestAnimationFrame(() => done())));
      milestones.mapInteractive = since();
    }
    const warmupDone = state.marks.some((mark) => mark.label.startsWith('deferred warm-up end'));
    const mapDone = !ENTRIES.some((entry) => entry.includes('map')) || milestones.mapInteractive !== undefined;
    // Warm-up does not start on every surface (or not before interaction),
    // so after the map is usable it gets a fixed grace window, the same for
    // every build, instead of holding the run until the overall timeout.
    const graceOver = milestones.mapInteractive !== undefined && since() - milestones.mapInteractive > WARMUP_GRACE_MS;
    if (mapDone && (warmupDone || graceOver)) break;
    await page.waitForTimeout(50);
  }
  await page.waitForTimeout(SETTLE_MS);
  const longTasks = await page.evaluate(() => window.__kubusLongTasks ?? null).catch(() => null);
  const heap = await page.evaluate(() => performance.memory?.usedJSHeapSize ?? null).catch(() => null);
  const markAt = (prefix) => state.marks.find((mark) => mark.label.startsWith(prefix))?.at;
  return {
    timings: {
      firstFrame: markAt('first frame'),
      shell: markAt('critical bootstrap end'),
      mapScreenInit: markAt('map screen init'),
      warmupEnd: markAt('deferred warm-up end'),
      mapCanvas: milestones.mapCanvas ?? null,
      mapTile: milestones.mapTile ?? null,
      mapInteractive: milestones.mapInteractive ?? null,
    },
    marks: state.marks.map(({ label, at, bootMs }) => ({ label, at, bootMs })),
    requests: state.requests.map(({ startedAt: requestStart, finishedAt, ...rest }) => ({
      ...rest,
      startMs: requestStart - navigationStart,
      endMs: finishedAt ? finishedAt - navigationStart : null,
    })),
    longTasks,
    usedJsHeap: heap,
    blockedWrites: [...state.blockedWrites],
  };
}

export function summarizeRequests(requests) {
  const byKind = {};
  const rpc = {};
  let bytes = 0;
  for (const request of requests) {
    byKind[request.kind] = (byKind[request.kind] ?? 0) + 1;
    for (const method of request.rpcMethods ?? []) rpc[method] = (rpc[method] ?? 0) + 1;
    bytes += request.bodyBytes ?? 0;
  }
  // A duplicate is the same method, URL and body requested again while an
  // earlier identical request is still open (concurrent), or again at all.
  const groups = new Map();
  for (const request of requests) {
    if (request.kind === 'map-tiles' || request.method === 'OPTIONS') continue;
    const key = `${request.method} ${request.url} ${request.body ?? ''}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(request);
  }
  const repeated = [];
  let concurrent = 0;
  for (const [key, entries] of groups) {
    if (entries.length < 2) continue;
    entries.sort((a, b) => a.startMs - b.startMs);
    let overlaps = 0;
    for (let index = 1; index < entries.length; index++) {
      const previous = entries[index - 1];
      if (previous.endMs === null || entries[index].startMs < previous.endMs) overlaps++;
    }
    concurrent += overlaps;
    repeated.push({ key: key.slice(0, 200), count: entries.length, concurrent: overlaps });
  }
  repeated.sort((a, b) => b.count - a.count);
  const appStaticBytes = requests.filter((request) => request.kind === 'app-static')
    .reduce((sum, request) => sum + (request.bodyBytes ?? 0), 0);
  return { total: requests.length, byKind, rpc, bytes, appStaticBytes, repeatedGets: repeated, concurrentDuplicates: concurrent };
}

async function runOne({ browserName, browser, viewport, scenario, entry, build, port, run }) {
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    serviceWorkers: 'block',
    locale: 'en-US',
  });
  await context.addInitScript(({ scenario: name, wallet }) => {
    window.__kubusLongTasks = { count: 0, totalMs: 0, maxMs: 0 };
    try {
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          const stats = window.__kubusLongTasks;
          stats.count++; stats.totalMs += entry.duration; stats.maxMs = Math.max(stats.maxMs, entry.duration);
        }
      }).observe({ type: 'longtask', buffered: true });
    } catch { window.__kubusLongTasks = null; }
    if (name === 'returning-wallet' && !sessionStorage.getItem('__kubusSeeded')) {
      sessionStorage.setItem('__kubusSeeded', '1');
      for (const key of ['wallet_address', 'walletAddress', 'wallet']) {
        localStorage.setItem(`flutter.${key}`, JSON.stringify(wallet));
      }
      localStorage.setItem('flutter.has_wallet', 'true');
    }
  }, { scenario, wallet: RETURNING_WALLET });
  const state = { requests: [], marks: [], blockedWrites: [] };
  if (API_ORIGIN) {
    // The production API admits only its own web origins, so a local build
    // would measure a 403 backend. Reads are replayed with the production
    // Origin and the CORS answer is rewritten for the local page. Writes
    // (analytics, wallet bootstrap, anything else) never reach production.
    const localOrigin = `http://127.0.0.1:${port}`;
    const cors = {
      'access-control-allow-origin': localOrigin,
      'access-control-allow-credentials': 'true',
      'access-control-allow-headers': '*',
      'access-control-allow-methods': 'GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS',
      'access-control-expose-headers': '*',
      vary: 'Origin',
    };
    await context.route(/^https:\/\/b?api\.kubus\.site\//, async (route) => {
      const request = route.request();
      const method = request.method();
      if (method === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
      if (method !== 'GET' && method !== 'HEAD') {
        state.blockedWrites.push(`${method} ${new URL(request.url()).pathname}`);
        return route.fulfill({ status: 204, headers: cors });
      }
      try {
        const response = await route.fetch({ headers: { ...request.headers(), origin: API_ORIGIN } });
        return route.fulfill({ response, headers: { ...response.headers(), ...cors } });
      } catch {
        return route.abort('failed');
      }
    });
  }
  const page = await context.newPage();
  const open = new Map();
  page.on('request', (request) => {
    const url = request.url();
    if (url.startsWith('data:') || url.startsWith('blob:')) return;
    const kind = classify(url);
    const body = request.method() === 'POST' ? request.postData() : null;
    const entry = {
      method: request.method(), url, kind, resourceType: request.resourceType(),
      startedAt: Date.now(), finishedAt: null, status: null, bodyBytes: null,
      body: kind === 'solana-rpc' ? body : null,
      rpcMethods: kind === 'solana-rpc' ? rpcMethods(body) : undefined,
    };
    open.set(request, entry);
    state.requests.push(entry);
  });
  const finish = async (request, failed) => {
    const entry = open.get(request);
    if (!entry) return;
    entry.finishedAt = Date.now();
    if (failed) { entry.status = 0; entry.failure = request.failure()?.errorText ?? 'failed'; return; }
    const response = await request.response().catch(() => null);
    entry.status = response?.status() ?? null;
    const sizes = await request.sizes().catch(() => null);
    entry.bodyBytes = sizes?.responseBodySize ?? null;
  };
  page.on('requestfinished', (request) => { finish(request, false); });
  page.on('requestfailed', (request) => { finish(request, true); });
  let loadStart = Date.now();
  page.on('console', (message) => {
    const text = message.text();
    const match = /\[BOOT\] (\d+)ms (.*)/.exec(text);
    if (match) state.marks.push({ label: match[2].trim(), bootMs: Number(match[1]), at: Date.now() - loadStart });
  });
  const url = `http://127.0.0.1:${port}${entry}`;
  const results = {};
  for (const phase of ['cold', 'warm']) {
    loadStart = Date.now();
    try {
      results[phase] = await measureLoad(page, url, loadStart, state);
    } catch (error) {
      results[phase] = { error: String(error?.message ?? error) };
    }
  }
  await context.close();
  return { browser: browserName, viewport: viewport.label, scenario, entry, build: build.label, run, ...results };
}

async function main() {
  checkBuilds();
  mkdirSync(OUT, { recursive: true });
  const servers = await Promise.all(BUILDS.map((build) => serve(build.dir)));
  const ports = servers.map((server) => server.address().port);
  const results = [];
  const launchers = { chromium, firefox };
  try {
    for (const browserName of BROWSERS) {
      const browser = await launchers[browserName].launch({ headless: true });
      try {
        for (const viewport of VIEWPORTS) for (const scenario of SCENARIOS) for (const entry of ENTRIES) {
          for (let run = 1; run <= RUNS; run++) {
            // Alternate which build goes first so ordering effects cancel out.
            const order = run % 2 ? BUILDS.map((_, i) => i) : BUILDS.map((_, i) => i).reverse();
            for (const index of order) {
              const result = await runOne({ browserName, browser, viewport, scenario, entry, build: BUILDS[index], port: ports[index], run });
              results.push(result);
              const cold = result.cold?.timings;
              console.log(`${browserName} ${viewport.label} ${scenario} ${entry} ${BUILDS[index].label} #${run}: ` +
                (result.cold?.error ? `ERROR ${result.cold.error}` :
                  `shell ${cold.shell} mapInteractive ${cold.mapInteractive} reqs ${result.cold.requests.length}`));
              writeFileSync(join(OUT, 'raw.json'), JSON.stringify(results, null, 1));
            }
          }
        }
      } finally {
        await browser.close();
      }
    }
  } finally {
    for (const server of servers) server.close();
  }
  writeFileSync(join(OUT, 'summary.json'), JSON.stringify(summarize(results), null, 1));
  console.log(`wrote ${join(OUT, 'raw.json')} and summary.json`);
}

export function summarize(results) {
  const groups = new Map();
  for (const result of results) {
    for (const phase of ['cold', 'warm']) {
      const load = result[phase];
      if (!load || load.error) continue;
      const key = [result.browser, result.viewport, result.scenario, result.entry, phase, result.build].join(' | ');
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(load);
    }
  }
  const rows = [];
  for (const [key, loads] of groups) {
    const [browser, viewport, scenario, entry, phase, build] = key.split(' | ');
    const timing = (name) => median(loads.map((load) => load.timings[name]));
    const requestSummaries = loads.map((load) => summarizeRequests(load.requests));
    const medianOf = (pick) => median(requestSummaries.map(pick));
    const kinds = [...new Set(requestSummaries.flatMap((summary) => Object.keys(summary.byKind)))];
    const rpcMethodsSeen = [...new Set(requestSummaries.flatMap((summary) => Object.keys(summary.rpc)))];
    rows.push({
      browser, viewport, scenario, entry, phase, build, samples: loads.length,
      medianMs: Object.fromEntries(['firstFrame', 'shell', 'mapScreenInit', 'mapCanvas', 'mapTile', 'mapInteractive', 'warmupEnd'].map((name) => [name, timing(name)])),
      medianRequests: medianOf((summary) => summary.total),
      medianByKind: Object.fromEntries(kinds.map((kind) => [kind, medianOf((summary) => summary.byKind[kind] ?? 0)])),
      medianRpcByMethod: Object.fromEntries(rpcMethodsSeen.map((method) => [method, medianOf((summary) => summary.rpc[method] ?? 0)])),
      medianConcurrentDuplicates: medianOf((summary) => summary.concurrentDuplicates),
      medianAppStaticBytes: medianOf((summary) => summary.appStaticBytes),
      medianLongTasks: median(loads.map((load) => load.longTasks?.count)),
      medianLongTaskMs: median(loads.map((load) => load.longTasks?.totalMs)),
      medianHeapBytes: median(loads.map((load) => load.usedJsHeap)),
      repeatedInFirstSample: requestSummaries[0]?.repeatedGets.slice(0, 12) ?? [],
    });
  }
  return rows;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => { console.error(error); process.exitCode = 1; });
}
