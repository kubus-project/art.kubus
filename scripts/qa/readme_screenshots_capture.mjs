// README / docs screenshot capture.
//
// Serves a prebuilt Flutter web bundle, lets read-only public GET requests
// reach the public API (so screens show real public content, never fixtures),
// stubs every non-GET request and analytics/diagnostics call, and captures the
// guest-reachable surfaces used by README.md and docs/SCREENSHOTS.md.
// The network policy mirrors scripts/qa/product_v5_wave4_capture.mjs.
//
//   flutter build web --release
//   node scripts/qa/readme_screenshots_capture.mjs
//
// QA_SCENARIOS=map,community limits the run to matching scenario names.
// QA_WEB_ROOT overrides the bundle directory (default build/web).
// Output: output/playwright/artifacts/readme/<scenario>.png + manifest.json.
// Copy the reviewed captures into docs/screenshots/ by hand; this script never
// writes into docs/ so a bad run cannot silently replace published images.
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const outDir = path.resolve(rootDir, 'output/playwright/artifacts/readme');
const port = Number(process.env.QA_PORT || 8098);
const appUrl = `http://127.0.0.1:${port}`;
const onlyScenarios = (process.env.QA_SCENARIOS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

// Ljubljana city centre: the densest cluster of public markers.
const GEOLOCATION = { latitude: 46.0511, longitude: 14.5051 };

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
    if (!file.startsWith(webRoot)) {
      res.writeHead(403).end();
      return;
    }
    try {
      const stat = await fs.stat(file);
      if (stat.isDirectory()) file = path.join(file, 'index.html');
    } catch {
      // SPA fallback: unknown paths render the app shell.
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
    const isAnalytics = /\/api\/(analytics|diagnostics|telemetry)/.test(url.pathname);
    const cors = {
      'access-control-allow-origin': appUrl,
      'access-control-allow-credentials': 'true',
      'access-control-allow-headers': '*',
      'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    };
    if (request.method() !== 'GET' || isAnalytics) {
      await route.fulfill({ status: 204, headers: cors, body: '' });
      return;
    }
    try {
      // The API rejects the local QA origin; public reads need no origin.
      const headers = { ...request.headers() };
      delete headers.origin;
      delete headers.referer;
      const response = await route.fetch({ timeout: 20000, headers });
      await route.fulfill({ response, headers: { ...response.headers(), ...cors } });
    } catch {
      await route.fulfill({ status: 503, headers: cors, body: '' });
    }
  });
  await page.route('https://accounts.google.com/gsi/client**', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/javascript',
      body: 'window.google={accounts:{id:{initialize(){},prompt(){},renderButton(){},cancel(){},disableAutoSelect(){}},oauth2:{initTokenClient:()=>({requestAccessToken(){}}),initCodeClient:()=>({requestCode(){}})}}};',
    }),
  );
}

async function seedPrefs(page, { language, onboarded }) {
  await page.addInitScript(
    ({ lang, done }) => {
      const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
      set('selected_language', JSON.stringify(lang));
      if (!done) return;
      set('has_completed_onboarding', 'true');
      set('has_seen_welcome', 'true');
      set('is_first_launch', 'false');
      set('skipOnboardingForReturningUsers', 'true');
      set('map_onboarding_mobile_seen_v2', 'true');
      set('map_onboarding_desktop_seen_v2', 'true');
    },
    { lang: language, done: onboarded },
  );
}

async function waitForApp(page) {
  await page.waitForFunction(
    () => Boolean(document.querySelector('flutter-view') || document.querySelector('flt-glass-pane')),
    { timeout: 60000 },
  );
  await page.waitForTimeout(6500);
}

async function enableSemantics(page) {
  await page.evaluate(() => {
    const el = document.querySelector('flt-semantics-placeholder');
    if (el) el.click();
  });
  await page.waitForTimeout(800);
}

async function clickText(page, text, { exact = false } = {}) {
  const locator = page.locator('flt-semantics').filter({
    hasText: exact ? new RegExp(`^\\s*${text}\\s*$`) : text,
  });
  if ((await locator.count()) === 0) {
    const byLabel = page.locator(`flt-semantics[aria-label*="${text}"]`);
    if ((await byLabel.count()) === 0) throw new Error(`No semantics node for "${text}"`);
    await byLabel.last().click({ force: true });
    return;
  }
  await locator.last().click({ force: true });
}

// QA_DUMP_LABELS=1 prints the semantics tree's buttons and labels, which is
// how the click targets below were found.
async function dumpLabels(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics[aria-label], flt-semantics[role=button]')]
      .map((e) => {
        const r = e.getBoundingClientRect();
        const label = e.getAttribute('aria-label') || e.textContent.trim().slice(0, 40);
        return `${e.getAttribute('role')}|${label}|${Math.round(r.x + r.width / 2)},${Math.round(r.y + r.height / 2)}`;
      })
      .join('\n'),
  );
}

// Mobile bottom navigation: five equal columns (map, ar, community, home, account).
async function tapMobileTab(page, viewport, index) {
  const x = Math.round((viewport.width / 5) * (index + 0.5));
  await page.mouse.click(x, viewport.height - 32);
  await page.waitForTimeout(2500);
}

const DESKTOP = { width: 1440, height: 900 };
const MOBILE = { width: 390, height: 844 };

const scenarios = [];
function add(name, viewport, theme, steps, { onboarded = true, reason = '' } = {}) {
  scenarios.push({ name, viewport, theme, steps, onboarded, reason });
}

async function openExplore(page) {
  await enableSemantics(page);
  await clickText(page, 'Explore', { exact: true });
  await page.waitForTimeout(6000);
}

// Flies to the context geolocation and lets markers for that viewport load.
async function centerOnMe(page, { zoomIn = true } = {}) {
  await enableSemantics(page);
  await clickText(page, 'Center on me', { exact: true });
  await page.waitForTimeout(7000);
  if (!zoomIn) return;
  // Desktop only: mobile keeps zoom behind the Map tools menu.
  await clickText(page, 'Zoom in', { exact: true });
  await page.waitForTimeout(5000);
}

// Moves the pointer off the controls so no hover tooltip is captured.
async function parkPointer(page) {
  await page.mouse.move(2, 2);
  await page.waitForTimeout(1200);
}

for (const theme of ['dark', 'light']) {
  add(`map-desktop-${theme}`, DESKTOP, theme, async (p) => {
    await openExplore(p);
    await centerOnMe(p);
    await clickText(p, 'Nearby artworks', { exact: true });
    await p.waitForTimeout(5000);
    await parkPointer(p);
  }, { reason: 'desktop map discovery' });
  add(`map-mobile-${theme}`, MOBILE, theme, async (p, v) => {
    await centerOnMe(p, { zoomIn: false });
    // Mobile keeps zoom buttons behind Map tools; wheel-zoom the canvas instead.
    await p.mouse.move(v.width / 2, v.height / 2);
    await p.mouse.wheel(0, -400);
    await p.waitForTimeout(6000);
    await p.mouse.wheel(0, -120);
    await p.waitForTimeout(6000);
    await parkPointer(p);
  }, {
    reason: 'mobile map (default tab)',
  });
  add(`map-card-desktop-${theme}`, DESKTOP, theme, async (p) => {
    await openExplore(p);
    await centerOnMe(p);
    await clickText(p, 'Nearby artworks', { exact: true });
    await p.waitForTimeout(5000);
    await clickText(p, 'Emonian Man');
    await p.waitForTimeout(6000);
    // Close the nearby panel (its close button is the right-most "Close") so
    // only the credited artwork photo remains in frame.
    const closes = p.locator('flt-semantics[role="button"][aria-label="Close"]');
    let best = null;
    for (const handle of await closes.all()) {
      const box = await handle.boundingBox();
      if (box && (!best || box.x > best.x)) best = box;
    }
    if (best) await p.mouse.click(best.x + best.width / 2, best.y + best.height / 2);
    await p.waitForTimeout(3000);
    await parkPointer(p);
  }, { reason: 'desktop map with an artwork opened from the nearby list' });
  add(`map-card-mobile-${theme}`, MOBILE, theme, async (p) => {
    await centerOnMe(p, { zoomIn: false });
    await clickText(p, 'Nearby art and places');
    await p.waitForTimeout(2500);
    await clickText(p, 'Laibach');
    await p.waitForTimeout(7000);
    await parkPointer(p);
  }, { reason: 'mobile map with an artwork opened from the nearby sheet' });
  add(`home-desktop-${theme}`, DESKTOP, theme, async () => {}, { reason: 'desktop home' });
  add(`community-desktop-${theme}`, DESKTOP, theme, async (p) => {
    await enableSemantics(p);
    await clickText(p, 'Connect', { exact: true });
    await p.waitForTimeout(5000);
  }, { reason: 'desktop community feed' });
  add(`community-mobile-${theme}`, MOBILE, theme, async (p, v) => {
    await tapMobileTab(p, v, 2);
    await p.waitForTimeout(3000);
  }, { reason: 'mobile community feed' });
  add(`onboarding-desktop-${theme}`, DESKTOP, theme, async () => {}, {
    onboarded: false,
    reason: 'first-launch onboarding',
  });
  add(`onboarding-mobile-${theme}`, MOBILE, theme, async () => {}, {
    onboarded: false,
    reason: 'first-launch onboarding',
  });
}

async function main() {
  await fs.mkdir(outDir, { recursive: true });
  await fs.access(path.join(webRoot, 'main.dart.js'));
  const server = await startServer();
  const browser = await chromium.launch();
  const manifest = [];
  try {
    for (const s of scenarios) {
      if (onlyScenarios.length && !onlyScenarios.some((o) => s.name.includes(o))) continue;
      const context = await browser.newContext({
        viewport: s.viewport,
        deviceScaleFactor: 2,
        colorScheme: s.theme,
        locale: 'en-US',
        geolocation: GEOLOCATION,
        permissions: ['geolocation'],
      });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', (e) => errors.push(String(e.message || e)));
      await installNetworkPolicy(page);
      await seedPrefs(page, { language: 'en', onboarded: s.onboarded });
      const entry = {
        screen: s.name,
        viewport: `${s.viewport.width}x${s.viewport.height}@2x`,
        theme: s.theme,
        auth: 'guest',
        reason: s.reason,
      };
      try {
        await page.goto(`${appUrl}/`, { waitUntil: 'domcontentloaded', timeout: 60000 });
        await waitForApp(page);
        await s.steps(page, s.viewport);
        if (process.env.QA_DUMP_LABELS) {
          await enableSemantics(page);
          console.log(await dumpLabels(page));
        }
        await page.screenshot({ path: path.join(outDir, `${s.name}.png`) });
        entry.status = 'captured';
      } catch (error) {
        entry.status = `failed: ${error.message}`;
        await page.screenshot({ path: path.join(outDir, `${s.name}.png`) }).catch(() => {});
      }
      entry.pageErrors = errors.slice(0, 5);
      manifest.push(entry);
      console.log(`${entry.status.padEnd(10).slice(0, 10)} ${s.name}`);
      await context.close();
    }
  } finally {
    await browser.close();
    server.close();
  }
  await fs.writeFile(
    path.join(outDir, 'manifest.json'),
    JSON.stringify({ webRoot: path.relative(rootDir, webRoot), captures: manifest }, null, 2),
  );
}

await main();
