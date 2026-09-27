// Wave 4 PRODUCT v5 before/after screen capture.
//
// Serves a prebuilt Flutter web bundle directory, lets read-only public GET
// requests reach the configured API (so screens show real public content),
// stubs every non-GET request and analytics/diagnostics call, and captures a
// fixed guest-state screen matrix. Run it against the BEFORE bundle and the
// AFTER bundle with different QA_LABEL values to produce comparable evidence.
//
//   QA_WEB_ROOT=../_tmp/wave4-before-web QA_LABEL=before node scripts/qa/product_v5_wave4_capture.mjs
//   QA_WEB_ROOT=build/web QA_LABEL=after node scripts/qa/product_v5_wave4_capture.mjs
//
// QA_SCENARIOS=home,settings limits the run to named scenarios.
// Output: output/playwright/product-v5-wave4/<label>/ + manifest.json
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const label = (process.env.QA_LABEL || 'after').trim();
const outDir = path.resolve(rootDir, 'output/playwright/product-v5-wave4', label);
const port = Number(process.env.QA_PORT || 8097);
const appUrl = `http://127.0.0.1:${port}`;
const onlyScenarios = (process.env.QA_SCENARIOS || '')
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
      // The browser would block the cross-origin response from 127.0.0.1;
      // fetch it outside the page and re-serve it with a local CORS grant.
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

async function seedPrefs(page, { language }) {
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
  const count = await locator.count();
  if (count === 0) {
    const byLabel = page.locator(`flt-semantics[aria-label*="${text}"]`);
    if ((await byLabel.count()) === 0) throw new Error(`No semantics node for "${text}"`);
    await byLabel.last().click({ force: true });
    return;
  }
  await locator.last().click({ force: true });
}

// Mobile bottom navigation has five equal columns in index order
// (map, ar, community, home, profile/account). Coordinates are used because
// the BEFORE shell exposes no labels to automation or assistive technology.
async function tapMobileTab(page, viewport, index) {
  const x = Math.round((viewport.width / 5) * (index + 0.5));
  const y = viewport.height - 32;
  await page.mouse.click(x, y);
  await page.waitForTimeout(2500);
}

const MOBILE = { width: 390, height: 844 };
const DESKTOP = { width: 1440, height: 900 };

// Each scenario: name, viewport, theme, language, steps(page) -> void.
const scenarios = [];
function add(name, viewport, theme, language, steps, reason) {
  scenarios.push({ name, viewport, theme, language, steps, reason });
}

for (const theme of ['light', 'dark']) {
  add(`mobile-map-${theme}-en`, MOBILE, theme, 'en', async () => {}, 'map surrounding UI, bottom nav');
  add(`mobile-home-${theme}-en`, MOBILE, theme, 'en', async (p, v) => tapMobileTab(p, v, 3), 'home hero/discovery');
  add(`mobile-community-${theme}-en`, MOBILE, theme, 'en', async (p, v) => tapMobileTab(p, v, 2), 'community feed');
  add(`mobile-account-${theme}-en`, MOBILE, theme, 'en', async (p, v) => tapMobileTab(p, v, 4), 'guest account tab');
  add(`desktop-home-${theme}-en`, DESKTOP, theme, 'en', async () => {}, 'desktop home + rail');
  add(`desktop-explore-${theme}-en`, DESKTOP, theme, 'en', async (p) => {
    await enableSemantics(p);
    await clickText(p, 'Explore', { exact: true });
    await p.waitForTimeout(3500);
  }, 'desktop map surrounding UI');
  add(`desktop-community-${theme}-en`, DESKTOP, theme, 'en', async (p) => {
    await enableSemantics(p);
    await clickText(p, 'Connect', { exact: true });
    await p.waitForTimeout(3500);
  }, 'desktop community');
}
add('mobile-home-light-sl', MOBILE, 'light', 'sl', async (p, v) => tapMobileTab(p, v, 3), 'home SL');
add('desktop-home-light-sl', DESKTOP, 'light', 'sl', async () => {}, 'desktop home SL');
add('mobile-settings-light-en', MOBILE, 'light', 'en', async (p, v) => {
  await tapMobileTab(p, v, 4);
  await enableSemantics(p);
  await clickText(p, 'Settings');
  await p.waitForTimeout(2500);
}, 'guest settings');
add('mobile-settings-dark-sl', MOBILE, 'dark', 'sl', async (p, v) => {
  await tapMobileTab(p, v, 4);
  await enableSemantics(p);
  await clickText(p, 'Nastavitve');
  await p.waitForTimeout(2500);
}, 'guest settings SL dark');
add('mobile-composer-guest-light-en', MOBILE, 'light', 'en', async (p, v) => {
  await tapMobileTab(p, v, 2);
  await enableSemantics(p);
  await clickText(p, 'New post');
  await p.waitForTimeout(2000);
}, 'guest tapping New post');
for (const width of [320, 360, 430, 768, 899]) {
  add(`w${width}-home-light-en`, { width, height: 860 }, 'light', 'en', async (p, v) => tapMobileTab(p, v, 3), `home at ${width}`);
}
for (const width of [900, 1024, 1280, 1920]) {
  add(`w${width}-home-light-en`, { width, height: 960 }, 'light', 'en', async () => {}, `desktop home at ${width}`);
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
        deviceScaleFactor: 1,
        colorScheme: s.theme,
        locale: s.language === 'sl' ? 'sl-SI' : 'en-US',
      });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', (e) => errors.push(String(e.message || e)));
      if (process.env.QA_DEBUG) {
        page.on('requestfinished', async (r) => {
          if (r.url().startsWith(appUrl)) return;
          const res = await r.response();
          console.log('  ', res?.status(), r.method(), r.url().slice(0, 150));
        });
        page.on('requestfailed', (r) =>
          console.log('   FAIL', r.method(), r.url().slice(0, 150), r.failure()?.errorText),
        );
      }
      await installNetworkPolicy(page);
      await seedPrefs(page, { language: s.language });
      const entry = {
        screen: s.name,
        route: '/',
        viewport: `${s.viewport.width}x${s.viewport.height}`,
        locale: s.language,
        theme: s.theme,
        auth: 'guest',
        reason: s.reason,
        path: `${label}/${s.name}.png`,
      };
      try {
        await page.goto(`${appUrl}/`, { waitUntil: 'domcontentloaded', timeout: 60000 });
        await waitForApp(page);
        await s.steps(page, s.viewport);
        const overflow = await page.evaluate(
          () => document.documentElement.scrollWidth > window.innerWidth + 1,
        );
        entry.horizontalOverflow = overflow;
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
  // Partial runs (QA_SCENARIOS) update their entries without dropping others.
  const manifestPath = path.join(outDir, 'manifest.json');
  let previous = [];
  try {
    previous = JSON.parse(await fs.readFile(manifestPath, 'utf8')).captures || [];
  } catch {
    previous = [];
  }
  const byScreen = new Map(previous.map((entry) => [entry.screen, entry]));
  for (const entry of manifest) byScreen.set(entry.screen, entry);
  await fs.writeFile(
    manifestPath,
    JSON.stringify(
      { label, webRoot: path.relative(rootDir, webRoot), captures: [...byScreen.values()] },
      null,
      2,
    ),
  );
}

await main();
