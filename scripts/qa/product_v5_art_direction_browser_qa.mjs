// Wave 5A-R art-direction browser QA.
//
// Serves a prebuilt Flutter web bundle and captures guest Home in a real
// Chromium: browser zoom (a half-size viewport at device scale 2 is exactly
// what 200 % page zoom gives a 1440x900 window), pointer hover on the
// destination tiles, and prefers-reduced-motion. Fully offline: every API,
// socket and third-party request is answered locally, so nothing reaches a
// production host and no analytics fire.
//
//   QA_WEB_ROOT=build/web QA_LABEL=after node scripts/qa/product_v5_art_direction_browser_qa.mjs
//
// QA_SCENARIOS=zoom,hover limits the run. Output:
// output/playwright/product-v5-art-direction/<label>/ + manifest.json
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const label = (process.env.QA_LABEL || 'after').trim();
const outDir = path.resolve(rootDir, 'output/playwright/product-v5-art-direction', label);
const port = Number(process.env.QA_PORT || 8098);
const appUrl = `http://127.0.0.1:${port}`;
const only = (process.env.QA_SCENARIOS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

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

async function offline(page) {
  const external = [];
  await page.routeWebSocket(/.*/, (ws) => ws.close());
  await page.route((url) => !url.toString().startsWith(appUrl), async (route) => {
    external.push(`${route.request().method()} ${route.request().url().slice(0, 120)}`);
    await route.fulfill({
      status: 503,
      headers: { 'access-control-allow-origin': appUrl, 'access-control-allow-credentials': 'true' },
      body: '',
    });
  });
  return external;
}

async function seedPrefs(page, language) {
  await page.addInitScript((lang) => {
    const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
    set('has_completed_onboarding', 'true');
    set('has_seen_welcome', 'true');
    set('is_first_launch', 'false');
    set('skipOnboardingForReturningUsers', 'true');
    set('map_onboarding_mobile_seen_v2', 'true');
    set('map_onboarding_desktop_seen_v2', 'true');
    set('selected_language', JSON.stringify(lang));
  }, language);
}

async function waitForApp(page) {
  await page.waitForFunction(
    () => Boolean(document.querySelector('flutter-view') || document.querySelector('flt-glass-pane')),
    { timeout: 60000 },
  );
  await page.waitForTimeout(6500);
}

async function tapMobileHome(page, viewport) {
  await page.mouse.click(Math.round((viewport.width / 5) * 3.5), viewport.height - 32);
  await page.waitForTimeout(2500);
}

const DESKTOP = { width: 1440, height: 900 };
const ZOOM200 = { width: 720, height: 450 };
const MOBILE = { width: 390, height: 844 };

// hover: [x, y] in CSS px, captured after a short and a settled delay.
const scenarios = [
  { name: 'desktop-home-dark-en', viewport: DESKTOP, theme: 'dark' },
  { name: 'desktop-home-light-en', viewport: DESKTOP, theme: 'light' },
  { name: 'desktop-home-dark-sl', viewport: DESKTOP, theme: 'dark', language: 'sl' },
  { name: 'zoom200-desktop-home-dark-en', viewport: ZOOM200, scale: 2, theme: 'dark', mobileHome: true },
  { name: 'zoom200-desktop-home-dark-en-scrolled', viewport: ZOOM200, scale: 2, theme: 'dark', mobileHome: true, scroll: [360, 380] },
  { name: 'mobile-home-dark-en', viewport: MOBILE, theme: 'dark', mobileHome: true },
  { name: 'w320-home-light-sl', viewport: { width: 320, height: 760 }, theme: 'light', language: 'sl', mobileHome: true },
  { name: 'hover-desktop-home-dark-en', viewport: DESKTOP, theme: 'dark', scroll: [640, 400], hoverFromEnv: true },
  { name: 'hover-reduced-desktop-home-dark-en', viewport: DESKTOP, theme: 'dark', reducedMotion: 'reduce', scroll: [640, 400], hoverFromEnv: true },
];

async function main() {
  await fs.mkdir(outDir, { recursive: true });
  await fs.access(path.join(webRoot, 'main.dart.js'));
  const hover = (process.env.QA_HOVER || '').split(',').map(Number);
  const server = await startServer();
  const browser = await chromium.launch();
  const manifest = [];
  try {
    for (const s of scenarios) {
      if (only.length && !only.some((o) => s.name.includes(o))) continue;
      const context = await browser.newContext({
        viewport: s.viewport,
        deviceScaleFactor: s.scale || 1,
        colorScheme: s.theme,
        reducedMotion: s.reducedMotion || 'no-preference',
        locale: s.language === 'sl' ? 'sl-SI' : 'en-US',
      });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', (e) => errors.push(String(e.message || e)));
      const external = await offline(page);
      await seedPrefs(page, s.language || 'en');
      await page.goto(appUrl, { waitUntil: 'domcontentloaded' });
      await waitForApp(page);
      if (s.mobileHome) await tapMobileHome(page, s.viewport);
      if (s.scroll) {
        await page.mouse.move(s.scroll[0], 200);
        await page.mouse.wheel(0, s.scroll[1]);
        await page.waitForTimeout(1200);
      }
      const shots = [];
      if (s.hoverFromEnv && hover.length === 2 && hover.every(Number.isFinite)) {
        await page.mouse.move(hover[0], hover[1] - 120);
        await page.waitForTimeout(600);
        const rest = `${s.name}-0-rest.png`;
        await page.screenshot({ path: path.join(outDir, rest) });
        await page.mouse.move(hover[0], hover[1]);
        await page.waitForTimeout(60);
        const early = `${s.name}-1-hover-60ms.png`;
        await page.screenshot({ path: path.join(outDir, early) });
        await page.waitForTimeout(700);
        const settled = `${s.name}-2-hover-settled.png`;
        await page.screenshot({ path: path.join(outDir, settled) });
        shots.push(rest, early, settled);
      } else {
        const file = `${s.name}.png`;
        await page.screenshot({ path: path.join(outDir, file) });
        shots.push(file);
      }
      manifest.push({
        name: s.name,
        viewport: s.viewport,
        deviceScaleFactor: s.scale || 1,
        theme: s.theme,
        reducedMotion: s.reducedMotion || 'no-preference',
        language: s.language || 'en',
        shots,
        pageErrors: errors,
        blockedExternalRequests: external.length,
      });
      console.log(`${s.name}: ${shots.length} shot(s), ${errors.length} page error(s)`);
      await context.close();
    }
  } finally {
    await browser.close();
    server.close();
  }
  await fs.writeFile(
    path.join(outDir, 'manifest.json'),
    JSON.stringify({ label, webRoot: path.relative(rootDir, webRoot), captures: manifest }, null, 2),
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
