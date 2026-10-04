// Map zoom-ladder capture: the real map, one viewport, a fixed place, a ladder
// of zoom levels, so grouping, unclustering, canonical markers and the first
// and later covers can be inspected level by level (and compared between two
// builds).
//
// Serves a prebuilt Flutter web bundle. Public GET reads reach the production
// API so the map shows real markers and covers; every write and analytics call
// is answered locally, so nothing is created and no telemetry is sent.
//
//   QA_WEB_ROOT=build/web QA_LABEL=081 node scripts/qa/map_zoom_ladder_capture.mjs
//
// Env: QA_ZOOMS=5,7,9,11,12,13,14,15   QA_VIEWPORTS=1440x900,390x844
//      QA_CENTER=14.5058,46.0519 (lng,lat)   QA_SETTLE_MS=4500
//      QA_SCHEME=light|dark   QA_GL=hardware|swiftshader   QA_PORT=8131
// Output: output/playwright/map-zoom-ladder/<label>/<w>x<h>-z<zoom>.png and
//         manifest.json (per level: features rendered, images, cover images).
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const label = (process.env.QA_LABEL || 'ladder').trim();
const outDir = path.resolve(rootDir, 'output/playwright/map-zoom-ladder', label);
const port = Number(process.env.QA_PORT || 8131);
const appUrl = `http://127.0.0.1:${port}`;
const settleMs = Number(process.env.QA_SETTLE_MS || 4500);
const scheme = process.env.QA_SCHEME || 'light';
const glMode = process.env.QA_GL || 'hardware';
const zooms = (process.env.QA_ZOOMS || '5,7,9,11,12,13,14,15').split(',').map(Number);
const [lng, lat] = (process.env.QA_CENTER || '14.5058,46.0519').split(',').map(Number);
const viewports = (process.env.QA_VIEWPORTS || '1440x900,390x844').split(',').map((v) => {
  const [width, height] = v.split('x').map(Number);
  return { width, height };
});

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.ico': 'image/x-icon',
  '.pbf': 'application/x-protobuf',
};

function startServer() {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, appUrl);
    let rel = decodeURIComponent(url.pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(webRoot, rel);
    if (path.relative(webRoot, file).startsWith('..')) return res.writeHead(403).end();
    try {
      if ((await fs.stat(file)).isDirectory()) file = path.join(file, 'index.html');
    } catch {
      file = path.join(webRoot, 'index.html');
    }
    try {
      const body = await fs.readFile(file);
      res.writeHead(200, {
        'content-type': MIME[path.extname(file)] || 'application/octet-stream',
        'cache-control': 'no-store',
      });
      res.end(body);
    } catch {
      res.writeHead(404).end();
    }
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}

async function installNetworkPolicy(page) {
  await page.routeWebSocket(/^wss:\/\/api\.kubus\.site\//, (ws) => {
    ws.onMessage((message) => {
      const text = message.toString();
      if (text === '2') ws.send('3');
      else if (text.startsWith('40')) ws.send('40{"sid":"qa-socket"}');
    });
    ws.send('0{"sid":"qa","upgrades":[],"pingInterval":25000,"pingTimeout":20000,"maxPayload":1000000}');
  });
  await page.route(/^https:\/\/(?:api|bapi)\.kubus\.site\//, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const cors = {
      'access-control-allow-origin': appUrl,
      'access-control-allow-credentials': 'true',
      'access-control-allow-headers': '*',
      'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    };
    if (request.method() !== 'GET' || /\/api\/(analytics|diagnostics|telemetry)/.test(url.pathname)) {
      await route.fulfill({ status: 204, headers: cors, body: '' });
      return;
    }
    try {
      const headers = { ...request.headers() };
      delete headers.origin;
      delete headers.referer;
      const response = await route.fetch({ timeout: 20000, headers });
      await route.fulfill({ response, headers: { ...response.headers(), ...cors } });
    } catch {
      await route.fulfill({ status: 503, headers: cors, body: '' });
    }
  });
}

const HOOK = () => {
  window.__maps = [];
  const timer = setInterval(() => {
    const proto = window.maplibregl && window.maplibregl.Map && window.maplibregl.Map.prototype;
    if (!proto || proto.__ladderHooked) return;
    proto.__ladderHooked = true;
    const setStyle = proto.setStyle;
    proto.setStyle = function (...args) {
      if (!window.__maps.includes(this)) window.__maps.push(this);
      return setStyle.apply(this, args);
    };
    clearInterval(timer);
  }, 2);
};

const args =
  glMode === 'hardware'
    ? ['--use-angle=d3d11', '--ignore-gpu-blocklist', '--enable-gpu-rasterization']
    : ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'];

const server = await startServer();
await fs.mkdir(outDir, { recursive: true });
const manifest = [];
const browser = await chromium.launch({ headless: true, args });
try {
  for (const viewport of viewports) {
    const context = await browser.newContext({
      viewport,
      deviceScaleFactor: 1,
      colorScheme: scheme,
      locale: 'en-US',
      hasTouch: viewport.width <= 480,
    });
    await context.addInitScript(() => {
      const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
      set('has_completed_onboarding', 'true');
      set('has_seen_welcome', 'true');
      set('is_first_launch', 'false');
      set('skipOnboardingForReturningUsers', 'true');
      set('map_onboarding_mobile_seen_v2', 'true');
      set('map_onboarding_desktop_seen_v2', 'true');
      set('selected_language', JSON.stringify('en'));
    });
    await context.addInitScript(HOOK);
    const page = await context.newPage();
    await installNetworkPolicy(page);
    await page.goto(`${appUrl}/map`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(
      () => {
        if (!window.__maps.length) return false;
        const m = window.__maps[window.__maps.length - 1];
        return (m.getStyle()?.layers || []).some((l) => l.id.startsWith('kubus_'));
      },
      null,
      { timeout: 120000 },
    );
    await page.waitForTimeout(4000);
    for (const zoom of zooms) {
      await page.evaluate(
        ({ lng, lat, zoom }) =>
          new Promise((resolve) => {
            const m = window.__maps[window.__maps.length - 1];
            m.once('idle', resolve);
            m.jumpTo({ center: [lng, lat], zoom });
            setTimeout(resolve, 15000);
          }),
        { lng, lat, zoom },
      );
      await page.waitForTimeout(settleMs);
      const stats = await page.evaluate(() => {
        const m = window.__maps[window.__maps.length - 1];
        const feats = m.querySourceFeatures('kubus_markers');
        const icons = new Set(feats.map((f) => String(f.properties?.icon || '')));
        const images = m.listImages ? m.listImages() : [];
        return {
          zoom: m.getZoom(),
          features: feats.length,
          clusters: feats.filter((f) => f.properties?.kind === 'cluster').length,
          coverIconsInUse: [...icons].filter((i) => i.startsWith('mc_')).length,
          coverImagesRegistered: images.filter((i) => i.startsWith('mc_')).length,
        };
      });
      const file = `${viewport.width}x${viewport.height}-z${zoom}.png`;
      await page.screenshot({ path: path.join(outDir, file) });
      manifest.push({ viewport: `${viewport.width}x${viewport.height}`, file, ...stats });
      console.log(file, JSON.stringify(stats));
    }
    await context.close();
  }
} finally {
  await browser.close();
  server.close();
}
await fs.writeFile(path.join(outDir, 'manifest.json'), JSON.stringify({ label, webRoot, glMode, scheme, center: [lng, lat], manifest }, null, 1));
