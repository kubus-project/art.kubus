// 0.8.1 tile / stat ghost-glyph browser QA.
//
// Serves a prebuilt Flutter web bundle fully offline (every API, socket and
// third-party request is answered locally) and captures real Chromium
// pointer hover on action tiles and stat cards: a rest frame with the pointer
// parked away, then a settled frame with the pointer on each target.
//
//   QA_WEB_ROOT=build/web QA_LABEL=081 QA_ROUTE=/settings QA_VIEWPORT=1440x900 \
//   QA_THEME=dark QA_HOVER="900,380;900,452" node scripts/qa/tile_hover_browser_qa.mjs
//
// QA_CLICKS="x,y;x,y" clicks (for example navigation) before the capture.
// QA_SCROLL=<px> wheels the page. QA_REDUCED=1 emulates prefers-reduced-motion. QA_MOBILE_TAB=<1-5> taps a
// phone bottom-navigation slot first. Output:
// output/playwright/tile-hover/<label>/<name>-*.png + <name>.json
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const label = (process.env.QA_LABEL || 'after').trim();
const outDir = path.resolve(rootDir, 'output/playwright/tile-hover', label);
const port = Number(process.env.QA_PORT || 8099);
const appUrl = `http://127.0.0.1:${port}`;
const route = process.env.QA_ROUTE || '/';
const [vw, vh] = (process.env.QA_VIEWPORT || '1440x900').split('x').map(Number);
const theme = process.env.QA_THEME || 'dark';
const reduced = process.env.QA_REDUCED === '1';
const mobileTab = Number(process.env.QA_MOBILE_TAB || 0);
const scroll = Number(process.env.QA_SCROLL || 0);
const clicks = (process.env.QA_CLICKS || '')
  .split(';')
  .map((p) => p.split(',').map(Number))
  .filter((p) => p.length === 2 && p.every(Number.isFinite));
const hovers = (process.env.QA_HOVER || '')
  .split(';')
  .map((p) => p.split(',').map(Number))
  .filter((p) => p.length === 2 && p.every(Number.isFinite));
const name =
  process.env.QA_NAME ||
  `${route.replace(/\W+/g, '-').replace(/^-|-$/g, '') || 'home'}-${vw}-${theme}${reduced ? '-reduced' : ''}`;

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
};

function startServer() {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, appUrl);
    let rel = decodeURIComponent(url.pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(webRoot, rel);
    if (!file.startsWith(webRoot)) {
      res.writeHead(403).end();
      return;
    }
    try {
      const stat = await fs.stat(file);
      if (stat.isDirectory()) file = path.join(file, 'index.html');
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

async function main() {
  await fs.mkdir(outDir, { recursive: true });
  await fs.access(path.join(webRoot, 'main.dart.js'));
  const server = await startServer();
  const browser = await chromium.launch();
  try {
    const context = await browser.newContext({
      viewport: { width: vw, height: vh },
      colorScheme: theme,
      reducedMotion: reduced ? 'reduce' : 'no-preference',
      locale: 'en-US',
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e.message || e)));
    let blocked = 0;
    await page.routeWebSocket(/.*/, (ws) => ws.close());
    await page.route((url) => !url.toString().startsWith(appUrl), async (r) => {
      blocked++;
      await r.fulfill({
        status: 503,
        headers: { 'access-control-allow-origin': appUrl, 'access-control-allow-credentials': 'true' },
        body: '',
      });
    });
    await page.addInitScript(() => {
      const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
      set('has_completed_onboarding', 'true');
      set('has_seen_welcome', 'true');
      set('is_first_launch', 'false');
      set('skipOnboardingForReturningUsers', 'true');
      set('map_onboarding_mobile_seen_v2', 'true');
      set('map_onboarding_desktop_seen_v2', 'true');
      set('selected_language', JSON.stringify('en'));
    });
    await page.goto(`${appUrl}${route}`, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(
      () => Boolean(document.querySelector('flutter-view') || document.querySelector('flt-glass-pane')),
      { timeout: 60000 },
    );
    await page.waitForTimeout(7000);
    if (mobileTab > 0) {
      await page.mouse.click(Math.round((vw / 5) * (mobileTab - 0.5)), vh - 32);
      await page.waitForTimeout(2500);
    }
    for (const [x, y] of clicks) {
      await page.mouse.click(x, y);
      await page.waitForTimeout(2500);
    }
    if (scroll) {
      await page.mouse.move(vw / 2, vh / 2);
      await page.mouse.wheel(0, scroll);
      await page.waitForTimeout(1200);
    }
    const shots = [];
    await page.mouse.move(2, vh - 2);
    await page.waitForTimeout(700);
    const rest = `${name}-0-rest.png`;
    await page.screenshot({ path: path.join(outDir, rest) });
    shots.push(rest);
    for (const [i, [x, y]] of hovers.entries()) {
      await page.mouse.move(2, vh - 2);
      await page.waitForTimeout(500);
      await page.mouse.move(x, y, { steps: 4 });
      await page.waitForTimeout(700);
      const file = `${name}-${i + 1}-hover-${x}x${y}.png`;
      await page.screenshot({ path: path.join(outDir, file) });
      shots.push(file);
    }
    await fs.writeFile(
      path.join(outDir, `${name}.json`),
      `${JSON.stringify({ name, route, viewport: [vw, vh], theme, reducedMotion: reduced, hovers, shots, pageErrors: errors, blockedExternalRequests: blocked }, null, 2)}\n`,
    );
    console.log(`${name}: ${shots.length} shot(s), ${errors.length} page error(s)`);
    await context.close();
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
