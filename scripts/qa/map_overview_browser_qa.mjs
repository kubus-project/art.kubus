// Low-zoom map overview: geography is preserved from world to street.
//
// Serves a built Flutter web bundle locally. Public API reads pass through to
// production except /api/art-markers/overview, which is answered by the
// backend's real service module (the grid and the counts are the product's) over
// a dataset, so the app can be checked before the endpoint is deployed.
//
//   QA_WEB_ROOT=build/web QA_DATASET=synthetic node scripts/qa/map_overview_browser_qa.mjs
//   QA_WEB_ROOT=build/web QA_DATASET=path/to/markers.json QA_LABEL=prod ...
//
// QA_DATASET=synthetic is the retained world fixture: 6,850 markers across 15
// cities on five continents (Lisbon, Madrid, Paris, Berlin, Rome, Stockholm,
// Moscow, Kyiv, Cairo, Ljubljana, New York, Tokyo, Sao Paulo, Nairobi, Sydney).
// A JSON file is an array of { id, latitude, longitude, type }.
//
// Env: QA_BACKEND_ROOT (default ../art.kubus-backend, a sibling checkout)
//      QA_VIEWPORT=1440x900  QA_LABEL=qa
// Asserts: the far map is drawn from overview nodes (more than one dot, never a
// single mega-cluster), detailed markers take over from zoom 9, the overview
// responses stay small, no 300-marker nearest-first fetch happens at far zoom.
// Exit code is non-zero on any failure.
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';

const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const backendRoot = path.resolve(rootDir, process.env.QA_BACKEND_ROOT || '../art.kubus-backend');
const overview = require(path.join(backendRoot, 'src/services/markerOverviewService.js'));

const dir = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const datasetPath = process.env.QA_DATASET || 'synthetic';
const label = process.env.QA_LABEL || 'qa';
const vwh = process.env.QA_VIEWPORT || '1440x900';
const planArg = process.env.QA_PLAN;
const [vw, vh] = vwh.split('x').map(Number);
const port = Number(process.env.QA_PORT || 8150);
const viewportWidth = Number(vwh.split('x')[0]);
const origin = `http://127.0.0.1:${port}`;
/** Deterministic world fixture: capitals and cities on five continents. */
function syntheticWorld() {
  const cities = {
    lisbon: [38.7223, -9.1393, 300], madrid: [40.4168, -3.7038, 700], paris: [48.8566, 2.3522, 900],
    berlin: [52.52, 13.405, 800], rome: [41.9028, 12.4964, 600], stockholm: [59.3293, 18.0686, 250],
    moscow: [55.7558, 37.6173, 500], kyiv: [50.4501, 30.5234, 350], cairo: [30.0444, 31.2357, 400],
    ljubljana: [46.0569, 14.5058, 450], newYork: [40.7128, -74.006, 500], tokyo: [35.6762, 139.6503, 400],
    saoPaulo: [-23.5505, -46.6333, 300], nairobi: [-1.2921, 36.8219, 150], sydney: [-33.8688, 151.2093, 250],
  };
  let seed = 42;
  const random = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 4294967296;
  };
  const out = [];
  let i = 0;
  for (const [, [lat, lng, n]] of Object.entries(cities)) {
    for (let k = 0; k < n; k += 1) {
      out.push({
        id: `w-${String(i++).padStart(5, '0')}`,
        latitude: lat + (random() - 0.5) * 0.12,
        longitude: lng + (random() - 0.5) * 0.18,
        type: k % 5 === 0 ? 'streetArt' : 'artwork',
      });
    }
  }
  return out;
}
const dataset = datasetPath === 'synthetic' ? syntheticWorld() : JSON.parse(await fs.readFile(path.resolve(rootDir, datasetPath), 'utf8'));
const plan = (
  planArg ||
  '2.6@30,10;3.6@47,10;4.6@47,12;5.5@46.5,14;7@46.2,14.5;9@46.06,14.5;12@46.06,14.5;14.5@46.056,14.505'
)
  .split(';')
  .map((step) => {
    const [z, c] = step.split('@');
    const [lat, lng] = c.split(',').map(Number);
    return { z: Number(z), lat, lng };
  });

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.otf': 'font/otf', '.woff2': 'font/woff2',
};
const root = path.resolve(dir);
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, origin);
  let rel = decodeURIComponent(url.pathname);
  if (rel.endsWith('/')) rel += 'index.html';
  let file = path.join(root, rel);
  try {
    if ((await fs.stat(file)).isDirectory()) file = path.join(file, 'index.html');
  } catch {
    file = path.join(root, 'index.html');
  }
  try {
    const body = await fs.readFile(file);
    res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
    res.end(body);
  } catch {
    res.writeHead(404).end();
  }
});
await new Promise((r) => server.listen(port, '127.0.0.1', r));

const stats = { overviewRequests: [], detailRequests: [] };
const browser = await chromium.launch({ args: ['--use-angle=d3d11', '--ignore-gpu-blocklist'] });
const ctx = await browser.newContext({ viewport: { width: vw, height: vh }, locale: 'en-US', ...(vw < 500 ? { isMobile: true, hasTouch: true } : {}) });
const cors = { 'access-control-allow-origin': origin, 'access-control-allow-credentials': 'true' };
await ctx.route(/api\.kubus\.site/, async (route) => {
  const request = route.request();
  const url = new URL(request.url());
  if (/analytics/.test(url.pathname)) return route.fulfill({ status: 204, body: '' });
  if (request.method() === 'OPTIONS') {
    return route.fulfill({ status: 204, headers: { ...cors, 'access-control-allow-methods': 'GET,POST,OPTIONS', 'access-control-allow-headers': '*' }, body: '' });
  }
  if (url.pathname === '/api/art-markers/overview') {
    const q = url.searchParams;
    const parsed = overview.parseOverviewQuery(Object.fromEntries(q.entries()));
    if (parsed.error) return route.fulfill({ status: 400, headers: cors, body: JSON.stringify({ success: false, error: parsed.error }) });
    const t0 = performance.now();
    const result = overview.aggregateMarkers(dataset, parsed);
    const body = JSON.stringify(overview.toResponse(result, parsed.zoom));
    stats.overviewRequests.push({ zoom: parsed.zoom, nodes: result.nodes.length, total: result.nodes.reduce((s, n) => s + n.count, 0), bytes: Buffer.byteLength(body), ms: +(performance.now() - t0).toFixed(1) });
    return route.fulfill({ status: 200, headers: { ...cors, 'content-type': 'application/json' }, body });
  }
  if (request.method() === 'GET') {
    try {
      const response = await route.fetch({ headers: { accept: request.headers().accept || 'application/json' } });
      if (url.pathname === '/api/art-markers') {
        const body = await response.body();
        stats.detailRequests.push({ limit: url.searchParams.get('limit'), bytes: body.length });
        return route.fulfill({ response, body, headers: { ...response.headers(), ...cors } });
      }
      return route.fulfill({ response, headers: { ...response.headers(), ...cors } });
    } catch {
      return route.fulfill({ status: 503, headers: cors, body: '' });
    }
  }
  return route.fulfill({ status: 503, headers: cors, body: '' });
});
await ctx.route((url) => url.origin !== origin && !/api\.kubus\.site|cartocdn|openstreetmap|basemaps|kubus\.site/.test(url.hostname), (r) => r.fulfill({ status: 503, body: '' }));

const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(String(e.message).slice(0, 160)));
await page.addInitScript(() => {
  window.__maps = [];
  window.__frames = [];
  const t = setInterval(() => {
    const p = window.maplibregl && window.maplibregl.Map && window.maplibregl.Map.prototype;
    if (!p || p.__h) return;
    p.__h = 1;
    const ss = p.setStyle;
    p.setStyle = function (...a) {
      if (!window.__maps.includes(this)) window.__maps.push(this);
      return ss.apply(this, a);
    };
    clearInterval(t);
  }, 5);
});
await page.goto(`${origin}/map`, { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => window.__maps.length && (window.__maps.at(-1).getStyle()?.layers || []).some((l) => l.id.startsWith('kubus_')), null, { timeout: 90000 });
await page.waitForTimeout(5000);

const outDir = path.resolve(rootDir, 'output/playwright/map-overview');
await fs.mkdir(outDir, { recursive: true });
const rows = [];
for (const step of plan) {
  await page.evaluate(([z, lat, lng]) => window.__maps.at(-1).jumpTo({ center: [lng, lat], zoom: z }), [step.z, step.lat, step.lng]);
  await page.waitForTimeout(7000);
  const state = await page.evaluate(() => {
    const m = window.__maps.at(-1);
    const bd = m.getBounds();
    const feats = {};
    for (const f of m.querySourceFeatures('kubus_markers')) {
      const pr = f.properties;
      if (!pr.id) continue;
      feats[pr.id] = { kind: pr.kind, count: pr.clusterCount ? Number(pr.clusterCount) : 1, ov: pr.overview === true || pr.overview === 'true', x: f.geometry.coordinates[0], y: f.geometry.coordinates[1] };
    }
    const list = Object.values(feats).filter((f) => f.x >= bd.getWest() && f.x <= bd.getEast() && f.y >= bd.getSouth() && f.y <= bd.getNorth());
    return {
      zoom: +m.getZoom().toFixed(2),
      features: list.length,
      overviewNodes: list.filter((f) => f.ov).length,
      represented: list.reduce((s, f) => s + (f.kind === 'cluster' ? f.count : 1), 0),
      individuals: list.filter((f) => f.kind !== 'cluster').length,
      big: list.filter((f) => f.kind === 'cluster').sort((a, b) => b.count - a.count).slice(0, 4).map((f) => f.count),
    };
  });
  rows.push({ ...step, ...state });
  console.log(JSON.stringify({ step, ...state }));
  await page.screenshot({ path: `${outDir}/${label}-${vw}-z${String(step.z).replace('.', '_')}.png` });
}
// A selected marker stays pinned: open it exactly, then zoom out into the
// overview band. It must be drawn on its own beside the overview nodes, never
// swallowed into an aggregate, and it must not depend on the overview at all.
const pinId = process.env.QA_PIN_MARKER_ID || '272620c6-c6a2-4711-8041-2c77955f4ad0';
let pinned = null;
try {
  await page.goto(`${origin}/en/map/${pinId}`, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(
    (id) => window.__maps.length && window.__maps.at(-1).querySourceFeatures('kubus_markers').some((f) => f.properties.id === id),
    pinId,
    { timeout: 60000 },
  );
  await page.waitForTimeout(6000);
  await page.evaluate(() => window.__maps.at(-1).jumpTo({ center: [12, 47], zoom: 4.6 }));
  await page.waitForTimeout(8000);
  pinned = await page.evaluate((id) => {
    const map = window.__maps.at(-1);
    const list = map.querySourceFeatures('kubus_markers').map((f) => f.properties);
    const nodes = new Set(list.filter((p) => p.overview === true || p.overview === 'true').map((p) => p.id));
    return {
      zoom: +map.getZoom().toFixed(2),
      overviewNodes: nodes.size,
      selectedDrawn: list.some((p) => p.id === id && p.kind !== 'cluster'),
    };
  }, pinId);
  console.log(JSON.stringify({ pinnedScenario: pinned }));
  await page.screenshot({ path: `${outDir}/${label}-${vw}-pinned-z4_6.png` });
} catch (error) {
  console.log(`pinned scenario failed: ${String(error).slice(0, 160)}`);
}

const failures = [];
const check = (ok, message) => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${message}`);
  if (!ok) failures.push(message);
};
const maxBytes = Math.max(0, ...stats.overviewRequests.map((r) => r.bytes));
for (const row of rows) {
  const tag = `z${row.z}`;
  if (row.z < 7.5) {
    check(row.overviewNodes > 0 && row.individuals === 0, `${tag}: drawn from overview nodes (${row.overviewNodes} nodes, ${row.individuals} individual markers)`);
    // Spread is asserted at world and continent scale only: a regional (or a
    // phone-width) viewport can legitimately hold one or two real places.
    if (row.z < 5) {
      check(row.features >= 2, `${tag}: more than one dot (${row.features})`);
      if (viewportWidth > 480) {
        const top = row.big[0] || 0;
        check(row.represented === 0 || top / row.represented <= 0.4, `${tag}: no mega-cluster (largest node ${top} of ${row.represented} represented)`);
      }
    }
  } else if (row.z >= 9) {
    check(row.overviewNodes === 0, `${tag}: detailed markers take over (no overview nodes)`);
  }
}
check(pinned !== null && pinned.overviewNodes > 0, `overview is drawn after zooming out from an open marker (${pinned?.overviewNodes ?? 0} nodes)`);
// Desktop closes an open marker on any user pan or zoom by design, so only the
// phone layout, which keeps the selection, can show it pinned through the move.
if (vw <= 480) {
  check(pinned !== null && pinned.selectedDrawn, 'the selected marker is still drawn on its own beside the overview nodes');
}
check(stats.overviewRequests.length > 0, `overview was requested (${stats.overviewRequests.length} requests)`);
check(maxBytes < 60 * 1024, `overview responses stay small (largest ${maxBytes} bytes)`);
check(stats.detailRequests.every((r) => Number(r.limit) >= 500 || r.limit === null), 'no 300-marker nearest-first fetch at far zoom');
check(errors.length === 0, `no page errors (${errors.length})`);

console.log('overview requests', JSON.stringify(stats.overviewRequests.slice(0, 12)));
console.log('detail requests', JSON.stringify(stats.detailRequests.slice(0, 12)));
console.log('page errors', JSON.stringify(errors.slice(0, 4)));
await fs.writeFile(`${outDir}/${label}-${vw}.json`, JSON.stringify({ rows, stats, errors }, null, 2));
await browser.close();
server.close();
process.exit(failures.length === 0 ? 0 : 1);
