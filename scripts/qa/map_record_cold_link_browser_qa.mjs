// Canonical map-record cold link: the exact marker is selected, its overlay
// opens, and the public takeover completes. Camera arrival alone is not enough.
//
// A cold /en/map/<markerId> link is served as semantic HTML with the Flutter app
// embedded behind it. The app flies to the marker, selects it, opens its overlay
// and only then reports the public entity ready, which removes the static page.
// A selection that is dismissed on the way (for example camera events of the
// flight read as a user pan) leaves the static page over the app forever.
//
// Two modes:
//
//   Local bundle, live semantic page (a candidate before it is deployed):
//     QA_WEB_ROOT=build/web QA_MARKER_IDS=<id>[,<id>] \
//       node scripts/qa/map_record_cold_link_browser_qa.mjs
//     The bundle is served from this process; the /en/map/<id> document is the
//     live semantic page (QA_SSR_ORIGIN, default https://app.kubus.site); public
//     API reads are proxied, every write and analytics call is answered locally.
//
//   Live origin (post-deploy acceptance):
//     QA_ORIGIN=https://app.kubus.site QA_MARKER_IDS=<id>[,<id>] \
//       node scripts/qa/map_record_cold_link_browser_qa.mjs
//
// Env: QA_VIEWPORTS=1440,390  QA_RUNS=2  QA_BROWSERS=chromium,firefox
//      QA_SETTLE_MS=25000  QA_LOCALE_PATH=en|sl
// Exit code is non-zero if any load fails.
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium, firefox } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const list = (name, fallback) =>
  (process.env[name] || fallback).split(',').map((s) => s.trim()).filter(Boolean);

const remoteOrigin = (process.env.QA_ORIGIN || '').replace(/[/]+$/, '');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const ssrOrigin = (process.env.QA_SSR_ORIGIN || 'https://app.kubus.site').replace(/[/]+$/, '');
const apiOrigin = process.env.QA_API_ORIGIN || 'https://api.kubus.site';
const markerIds = list('QA_MARKER_IDS', '');
const widths = list('QA_VIEWPORTS', '1440,390').map(Number);
const browsers = list('QA_BROWSERS', 'chromium');
const runs = Number(process.env.QA_RUNS || 2);
const settleMs = Number(process.env.QA_SETTLE_MS || 25000);
const localePath = process.env.QA_LOCALE_PATH === 'sl' ? 'sl/zemljevid' : 'en/map';
const port = Number(process.env.QA_PORT || 8140);
const localOrigin = `http://127.0.0.1:${port}`;
const appOrigin = remoteOrigin || localOrigin;

if (markerIds.length === 0) {
  console.error('QA_MARKER_IDS is required (one or more art marker ids).');
  process.exit(2);
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
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
};

/** Serves the bundle; the map-record document is the live semantic page. */
function startLocalServer(semanticPages) {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, localOrigin);
    let rel = decodeURIComponent(url.pathname);
    const semantic = semanticPages.get(rel);
    if (semantic) {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
      res.end(semantic);
      return;
    }
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(webRoot, rel);
    if (!file.startsWith(webRoot)) {
      res.writeHead(403).end();
      return;
    }
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

/** Public API reads pass through; analytics and every write stay local. */
async function containNetwork(context) {
  await context.route((url) => url.origin === new URL(apiOrigin).origin, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (/\/api\/analytics\b/.test(url.pathname)) return route.fulfill({ status: 204, body: '' });
    if (remoteOrigin) {
      if (request.method() === 'GET' || request.method() === 'OPTIONS') return route.continue();
      return route.fulfill({ status: 503, body: '' });
    }
    const cors = {
      'access-control-allow-origin': appOrigin,
      'access-control-allow-credentials': 'true',
    };
    if (request.method() === 'GET') {
      try {
        const response = await route.fetch({
          headers: { accept: request.headers().accept || 'application/json' },
        });
        return route.fulfill({ response, headers: { ...response.headers(), ...cors } });
      } catch {
        return route.fulfill({ status: 503, body: '' });
      }
    }
    if (request.method() === 'OPTIONS') {
      return route.fulfill({
        status: 204,
        headers: {
          ...cors,
          'access-control-allow-methods': 'GET,POST,OPTIONS',
          'access-control-allow-headers': '*',
        },
        body: '',
      });
    }
    return route.fulfill({ status: 503, headers: cors, body: '' });
  });
  if (!remoteOrigin) {
    await context.route(
      (url) =>
        url.origin !== localOrigin &&
        url.origin !== new URL(apiOrigin).origin &&
        !/kubus\.site|cartocdn|openstreetmap|basemaps/.test(url.hostname),
      (route) => route.fulfill({ status: 503, body: '' }),
    );
  }
}

async function loadOne({ browserType, name, width, markerId, index }) {
  const browser = await browserType.launch(
    name === 'chromium' ? { args: ['--use-angle=d3d11', '--ignore-gpu-blocklist'] } : {},
  );
  try {
    const mobile = width <= 480;
    const context = await browser.newContext({
      viewport: { width, height: mobile ? 844 : 900 },
      // Firefox needs an explicit locale to boot the app.
      locale: 'en-US',
      ...(mobile && name === 'chromium' ? { isMobile: true, hasTouch: true } : {}),
    });
    await containNetwork(context);
    const page = await context.newPage();
    await page.addInitScript(() => {
      window.__qa = { ready: [], completed: [] };
      addEventListener('kubus:public-entity-ready', (event) =>
        window.__qa.ready.push({ at: Math.round(performance.now()), detail: event.detail }),
      );
      addEventListener('kubus:flutter-takeover-completed', () =>
        window.__qa.completed.push(Math.round(performance.now())),
      );
    });
    const route = `/${localePath}/${markerId}`;
    await page.goto(`${appOrigin}${route}`, { waitUntil: 'domcontentloaded' });
    // Wait on the contract itself, not a fixed delay: ready, or the settle cap.
    const ready = await page
      .waitForFunction(() => window.__qa.ready.length > 0, null, { timeout: settleMs })
      .then(() => true)
      .catch(() => false);
    await page.waitForTimeout(ready ? 1500 : 0);
    const state = await page.evaluate(() => ({
      path: location.pathname,
      ready: window.__qa.ready,
      completed: window.__qa.completed,
      html: document.documentElement.className,
      title: document.title,
    }));
    const shot = path.join(rootDir, 'output/playwright/map-record-cold-link');
    await fs.mkdir(shot, { recursive: true });
    await page.screenshot({
      path: path.join(shot, `${name}-${width}-${markerId.slice(0, 8)}-${index}.png`),
    });
    const exactlyOnce = state.ready.length === 1;
    const sameEntity =
      exactlyOnce &&
      state.ready[0].detail &&
      JSON.parse(
        typeof state.ready[0].detail === 'string'
          ? state.ready[0].detail
          : JSON.stringify(state.ready[0].detail),
      ).id === markerId;
    return {
      name,
      width,
      markerId,
      path: state.path,
      readyAtMs: state.ready[0]?.at ?? null,
      readyCount: state.ready.length,
      takeoverCompleted: state.completed.length > 0,
      ok:
        ready &&
        exactlyOnce &&
        Boolean(sameEntity) &&
        state.path.endsWith(markerId) &&
        state.completed.length > 0,
    };
  } finally {
    await browser.close();
  }
}

async function main() {
  const semanticPages = new Map();
  let server = null;
  if (!remoteOrigin) {
    await fs.access(path.join(webRoot, 'main.dart.js'));
    for (const markerId of markerIds) {
      const route = `/${localePath}/${markerId}`;
      const response = await fetch(`${ssrOrigin}${route}`);
      if (!response.ok) throw new Error(`semantic page ${route} answered ${response.status}`);
      semanticPages.set(route, await response.text());
    }
    server = await startLocalServer(semanticPages);
  }
  const results = [];
  try {
    for (const name of browsers) {
      const browserType = name === 'firefox' ? firefox : chromium;
      for (const width of widths) {
        for (const markerId of markerIds) {
          for (let index = 0; index < runs; index += 1) {
            const result = await loadOne({ browserType, name, width, markerId, index });
            results.push(result);
            console.log(
              `${result.ok ? 'ok  ' : 'FAIL'} ${name} ${width} ${markerId.slice(0, 8)}#${index} ` +
                `ready=${result.readyCount} at=${result.readyAtMs ?? '-'}ms ` +
                `takeover=${result.takeoverCompleted}`,
            );
          }
        }
      }
    }
  } finally {
    server?.close();
  }
  const failed = results.filter((r) => !r.ok);
  console.log(`${results.length - failed.length}/${results.length} cold links completed`);
  process.exit(failed.length === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
