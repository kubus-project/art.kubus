// Wave 5B: CPU profile of the camera path for ONE bundle (chromium, CDP Profiler).
//   PROFILE_DIR=C:/kubus-build/perf/B PROFILE_VIEWPORT=1440x900 node scripts/qa/product_v5_spatial_cpu_profile.mjs
// Prints the top self-time functions and the phase split of the main thread.
// Reuses the fixture recorded by product_v5_spatial_perf_ab.mjs (no network cost).
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const dir = path.resolve(process.env.PROFILE_DIR);
const [width, height] = (process.env.PROFILE_VIEWPORT || '1440x900').split('x').map(Number);
const fixtureDir = path.resolve(root, 'output/playwright/spatial/perf-fixture');
const markersFile = path.resolve(root, 'output/playwright/spatial/perf-fixture-markers.json');
const port = 8190;
const origin = `http://127.0.0.1:${port}`;
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.css': 'text/css', '.png': 'image/png', '.otf': 'font/otf', '.ttf': 'font/ttf' };
const server = http.createServer(async (req, res) => {
  let rel = decodeURIComponent(new URL(req.url, origin).pathname);
  if (rel.endsWith('/')) rel += 'index.html';
  let file = path.join(dir, rel);
  try { if ((await fs.stat(file)).isDirectory()) file = path.join(file, 'index.html'); } catch { file = path.join(dir, 'index.html'); }
  try { res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' }); res.end(await fs.readFile(file)); } catch { res.writeHead(404).end(); }
});
await new Promise((r) => server.listen(port, '127.0.0.1', r));
const browser = await chromium.launch({ headless: true, args: process.env.PROFILE_GL === 'hardware' ? ['--use-angle=d3d11', '--ignore-gpu-blocklist'] : ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
const apiOrigin = 'https://api.kubus.site';
await context.route('**/*', async (route) => {
  const request = route.request();
  const url = new URL(request.url());
  if (url.origin === origin && !url.pathname.startsWith('/api/')) return route.continue();
  const cors = { 'access-control-allow-origin': request.headers().origin || origin, 'access-control-allow-credentials': 'true' };
  if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: { ...cors, 'access-control-allow-methods': 'GET,OPTIONS', 'access-control-allow-headers': '*' }, body: '' });
  if (request.method() !== 'GET') return route.fulfill({ status: 204, body: '' });
  if (url.pathname === '/api/art-markers') return route.fulfill({ status: 200, headers: { 'content-type': 'application/json', ...cors }, body: await fs.readFile(markersFile) });
  const target = url.origin === origin ? `${apiOrigin}${url.pathname}${url.search}` : request.url();
  const key = crypto.createHash('sha1').update(`GET ${target}`).digest('hex');
  try {
    const meta = JSON.parse(await fs.readFile(path.join(fixtureDir, `${key}.json`), 'utf8'));
    return route.fulfill({ status: meta.status, headers: { ...meta.headers, ...cors }, body: await fs.readFile(path.join(fixtureDir, `${key}.bin`)) });
  } catch { return route.fulfill({ status: 503, body: '' }); }
});
await context.addInitScript(() => {
  window.__maps = [];
  const t = setInterval(() => {
    const p = window.maplibregl?.Map?.prototype;
    if (!p || p.__h) return;
    p.__h = true;
    const s = p.setStyle;
    p.setStyle = function (...a) { if (!window.__maps.includes(this)) window.__maps.push(this); return s.apply(this, a); };
    clearInterval(t);
  }, 2);
});
const page = await context.newPage();
await page.goto(`${origin}/map`, { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => window.__maps.length && (window.__maps.at(-1).getStyle()?.layers || []).some((l) => l.id.startsWith('kubus_')), null, { timeout: 90000 });
await page.waitForTimeout(8000);
const cdp = await context.newCDPSession(page);
await cdp.send('Profiler.enable');
await cdp.send('Profiler.setSamplingInterval', { interval: 200 });
await cdp.send('Profiler.start');
await page.evaluate(() => new Promise((resolve) => {
  const map = window.__maps.at(-1);
  map.jumpTo({ zoom: 3.5, center: [14.5058, 46.0569] });
  setTimeout(() => map.easeTo({ zoom: 15, duration: 2500 }), 400);
  setTimeout(() => map.easeTo({ center: [14.5258, 46.0769], duration: 1200 }), 3200);
  setTimeout(() => map.easeTo({ zoom: 6, duration: 1800 }), 4600);
  setTimeout(resolve, 6800);
}));
const { profile } = await cdp.send('Profiler.stop');
await browser.close();
server.close();
const byId = new Map(profile.nodes.map((n) => [n.id, n]));
const self = new Map();
const dt = profile.timeDeltas;
profile.samples.forEach((id, i) => self.set(id, (self.get(id) || 0) + (dt[i] || 0)));
const agg = new Map();
let total = 0;
for (const [id, us] of self) {
  const n = byId.get(id);
  const f = n.callFrame;
  const key = `${f.functionName || '(anon)'} ${path.basename(f.url || '') || ''}:${f.lineNumber}`;
  agg.set(key, (agg.get(key) || 0) + us);
  total += us;
}
const idle = (agg.get('(idle) :-1') || 0) + (agg.get('(program) :-1') || 0);
console.log(`total sampled ${(total / 1000).toFixed(0)} ms, idle+program ${(idle / 1000).toFixed(0)} ms, busy ${((total - idle) / 1000).toFixed(0)} ms`);
const byFile = new Map();
for (const [id, us] of self) {
  const f = byId.get(id).callFrame;
  const k = path.basename(f.url || '(native)') || '(native)';
  byFile.set(k, (byFile.get(k) || 0) + us);
}
console.log('--- self time by script');
[...byFile].sort((a, b) => b[1] - a[1]).slice(0, 8).forEach(([k, us]) => console.log(`${(us / 1000).toFixed(0).padStart(6)} ms  ${k}`));
console.log('--- top self-time functions');
[...agg].sort((a, b) => b[1] - a[1]).slice(0, 22).forEach(([k, us]) => console.log(`${(us / 1000).toFixed(0).padStart(6)} ms  ${k}`));
