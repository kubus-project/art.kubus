// 0.8.0 release audit: PRODUCT surface x viewport x theme x language capture.
//
// Serves a prebuilt Flutter web bundle and renders each guest-reachable surface
// across the acceptance matrix. Public GET reads reach the production API so the
// surfaces show real content; every write and analytics call is answered
// locally, so nothing is created and no telemetry is sent.
//
//   QA_WEB_ROOT=build/web QA_LABEL=audit node scripts/qa/product_v5_release_audit_capture.mjs
//
// Env: QA_SURFACES=home,map limits surfaces (substring match)
//      QA_WIDTHS=320,390,768,1440,1920   QA_SCHEMES=light,dark   QA_LOCALES=en,sl
//      QA_TIER=all|a|b   QA_CONCURRENCY=3   QA_SETTLE_MS=7000
// Output: output/playwright/release-audit/<label>/<surface>/<w>-<scheme>-<lang>.png,
//         manifest.json, and one contact sheet per surface and language.
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const label = (process.env.QA_LABEL || 'audit').trim();
const outDir = path.resolve(rootDir, 'output/playwright/release-audit', label);
const port = Number(process.env.QA_PORT || 8099);
const appUrl = `http://127.0.0.1:${port}`;
const concurrency = Number(process.env.QA_CONCURRENCY || 3);
const settleMs = Number(process.env.QA_SETTLE_MS || 7000);
const list = (name, fallback) =>
  (process.env[name] || fallback).split(',').map((s) => s.trim()).filter(Boolean);
const widths = list('QA_WIDTHS', '320,390,768,1440,1920').map(Number);
const schemes = list('QA_SCHEMES', 'light,dark');
const locales = list('QA_LOCALES', 'en,sl');
const onlySurfaces = list('QA_SURFACES', '');
const tier = (process.env.QA_TIER || 'all').toLowerCase();

const ARTWORK = 'd3e5b3a5-d1f4-4213-85e7-c85dee331ce1';
const ARTIST = '067b604c-3e37-4eb6-b140-f189fe546d3e';
const INSTITUTION = 'b5218a75-9066-4e20-9fd0-51c1d4ca93d2';
const COLLECTION = 'f51b9b4f-574f-4970-bfab-49c71f7bf073';

// Tier A: the full matrix. Tier B: a reduced matrix (320, 768, 1440; light and
// dark in English plus Slovenian light) for secondary and flow surfaces.
const surfaces = [
  { id: 'home', tier: 'a', path: '/main', nav: 'home' },
  { id: 'map', tier: 'a', path: '/map' },
  { id: 'artwork', tier: 'a', path: `/en/artworks/${ARTWORK}` },
  { id: 'artist-profile', tier: 'a', path: `/en/profiles/${ARTIST}` },
  { id: 'community', tier: 'a', path: '/community', nav: 'community' },
  { id: 'account-guest', tier: 'a', path: '/main', nav: 'account' },
  { id: 'infrastructure', tier: 'b', path: '/main', nav: 'infrastructure', minWidth: 900 },
  { id: 'sign-in', tier: 'a', path: '/sign-in' },
  { id: 'register', tier: 'a', path: '/register' },
  { id: 'settings', tier: 'a', path: '/settings' },
  { id: 'institution-profile', tier: 'b', path: `/en/profiles/${INSTITUTION}` },
  { id: 'collection', tier: 'b', path: `/en/collections/${COLLECTION}` },
  { id: 'event-not-found', tier: 'b', path: '/en/events/00000000-0000-4000-8000-000000000000' },
  { id: 'exhibition-not-found', tier: 'b', path: '/en/exhibitions/00000000-0000-4000-8000-000000000000' },
  { id: 'post-not-found', tier: 'b', path: '/en/posts/00000000-0000-4000-8000-000000000000' },
  { id: 'artwork-not-found', tier: 'b', path: '/en/artworks/00000000-0000-4000-8000-000000000000' },
  { id: 'marketplace', tier: 'b', path: '/marketplace' },
  { id: 'wallet', tier: 'b', path: '/wallet' },
  { id: 'connect-wallet', tier: 'b', path: '/connect-wallet' },
  { id: 'web3', tier: 'b', path: '/web3' },
  { id: 'ar', tier: 'b', path: '/ar' },
  { id: 'onboarding', tier: 'b', path: '/onboarding' },
  { id: 'forgot-password', tier: 'b', path: '/forgot-password' },
  { id: 'verify-email', tier: 'b', path: '/verify-email?token=qa-token&email=qa%40kubus.site' },
  { id: 'promotions', tier: 'b', path: '/promotions?status=success&session_id=cs_test_qa' },
  { id: 'offline-home', tier: 'b', path: '/main', offline: true },
  { id: 'offline-map', tier: 'b', path: '/map', offline: true },
];

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
    let rel;
    try {
      rel = decodeURIComponent(url.pathname);
    } catch {
      res.writeHead(400).end();
      return;
    }
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(webRoot, rel);
    if (path.relative(webRoot, file).startsWith('..')) {
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

async function installNetworkPolicy(page, { offline }) {
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
    if (offline) {
      await route.abort('internetdisconnected');
      return;
    }
    const isAnalytics = /\/api\/(analytics|diagnostics|telemetry)/.test(url.pathname);
    if (request.method() !== 'GET' || isAnalytics) {
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
  await page.route('https://accounts.google.com/gsi/client**', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/javascript',
      body: 'window.google={accounts:{id:{initialize(){},prompt(){},renderButton(){},cancel(){},disableAutoSelect(){}},oauth2:{initTokenClient:()=>({requestAccessToken(){}}),initCodeClient:()=>({requestCode(){}})}}};',
    }),
  );
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

/** Bottom tabs on phones and tablets; the semantic rail labels on desktop. */
async function navigateShell(page, nav, width, height, language) {
  if (width < 900) {
    const index = { map: 0, ar: 1, community: 2, home: 3, account: 4 }[nav];
    if (index === undefined) return;
    await page.mouse.click(Math.round((width / 5) * (index + 0.5)), height - 32);
  } else {
    const labels = language === 'sl'
      ? { home: 'Domov', community: 'Poveži', account: 'Prijava', infrastructure: 'Infrastruktura' }
      : { home: 'Home', community: 'Connect', account: 'Sign in', infrastructure: 'Infrastructure' };
    const text = labels[nav];
    if (!text) return;
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(800);
    await page.getByRole('button', { name: text, exact: true }).first().click({ force: true, timeout: 8000 });
  }
  await page.waitForTimeout(3500);
}

function heightFor(width) {
  if (width <= 320) return 700;
  if (width <= 430) return 844;
  if (width <= 768) return 1024;
  if (width <= 1440) return 900;
  return 1080;
}

function jobsFor(surface) {
  const reduced = surface.tier === 'b';
  const jobWidths = (reduced ? widths.filter((w) => [320, 768, 1440].includes(w)) : widths).filter((w) => w >= (surface.minWidth || 0));
  const jobs = [];
  for (const language of locales) {
    for (const scheme of schemes) {
      // Reduced tier: Slovenian light only.
      if (reduced && language === 'sl' && scheme === 'dark') continue;
      for (const width of jobWidths) {
        jobs.push({ surface, language, scheme, width, height: heightFor(width) });
      }
    }
  }
  return jobs;
}

async function capture(browser, job) {
  const { surface, language, scheme, width, height } = job;
  const rel = path.join(surface.id, `${width}-${scheme}-${language}.png`);
  const entry = {
    surface: surface.id,
    path: surface.path,
    viewport: `${width}x${height}`,
    theme: scheme,
    locale: language,
    auth: 'guest',
    file: rel.replaceAll('\\', '/'),
  };
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: 1,
    colorScheme: scheme,
    locale: language === 'sl' ? 'sl-SI' : 'en-US',
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e.message || e).slice(0, 200)));
  try {
    await installNetworkPolicy(page, { offline: Boolean(surface.offline) });
    await seedPrefs(page, language);
    await page.goto(`${appUrl}${surface.path}`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForFunction(
      () => Boolean(document.querySelector('flutter-view') || document.querySelector('flt-glass-pane')),
      { timeout: 60000 },
    );
    await page.waitForTimeout(settleMs);
    if (surface.nav) await navigateShell(page, surface.nav, width, height, language);
    entry.finalUrl = new URL(page.url()).pathname + new URL(page.url()).search;
    entry.horizontalOverflow = await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth + 1,
    );
    await page.screenshot({ path: path.join(outDir, rel) });
    entry.status = 'captured';
  } catch (error) {
    entry.status = `failed: ${String(error.message).slice(0, 120)}`;
    await page.screenshot({ path: path.join(outDir, rel) }).catch(() => {});
  }
  entry.pageErrors = errors.slice(0, 3);
  await context.close();
  return entry;
}

async function pool(items, size, worker) {
  const results = [];
  let next = 0;
  async function run() {
    while (next < items.length) {
      const index = next++;
      results[index] = await worker(items[index]);
    }
  }
  await Promise.all(Array.from({ length: size }, run));
  return results;
}

/** One contact sheet per surface and language so a whole row can be read at once. */
async function contactSheets(browser, manifest) {
  const groups = new Map();
  for (const entry of manifest) {
    const key = `${entry.surface}|${entry.locale}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(entry);
  }
  for (const [key, entries] of groups) {
    const [surface, language] = key.split('|');
    const cells = entries
      .map((entry) => {
        const [w] = entry.viewport.split('x').map(Number);
        const thumbWidth = Math.min(Math.max(Math.round(w / 2.6), 190), 560);
        const src = `file:///${path.join(outDir, entry.file).replaceAll('\\', '/')}`;
        return `<figure style="margin:0;display:inline-block;vertical-align:top;width:${thumbWidth}px">
          <img src="${src}" style="width:${thumbWidth}px;border:1px solid #888;display:block">
          <figcaption style="font:11px monospace;color:#222">${entry.viewport} ${entry.theme}${entry.horizontalOverflow ? ' OVERFLOW' : ''}${entry.status !== 'captured' ? ' FAILED' : ''}</figcaption></figure>`;
      })
      .join('\n');
    const html = `<html><body style="margin:8px;background:#ddd;font-family:monospace"><div style="display:flex;flex-wrap:wrap;gap:8px;align-items:flex-start">${cells}</div></body></html>`;
    const sheetPath = path.join(outDir, `sheet-${surface}-${language}.png`);
    const page = await browser.newPage({ viewport: { width: 2000, height: 800 } });
    const htmlPath = path.join(outDir, `sheet-${surface}-${language}.html`);
    await fs.writeFile(htmlPath, html);
    await page.goto(`file:///${htmlPath.split(path.sep).join('/')}`);
    await page.waitForTimeout(400);
    await page.screenshot({ path: sheetPath, fullPage: true });
    await page.close();
    await fs.rm(htmlPath, { force: true });
  }
}

async function main() {
  await fs.mkdir(outDir, { recursive: true });
  await fs.access(path.join(webRoot, 'main.dart.js'));
  const server = await startServer();
  const browser = await chromium.launch();
  const selected = surfaces
    .filter((s) => tier === 'all' || s.tier === tier)
    .filter((s) => !onlySurfaces.length || onlySurfaces.some((o) => s.id.includes(o)));
  for (const s of selected) await fs.mkdir(path.join(outDir, s.id), { recursive: true });
  const jobs = selected.flatMap(jobsFor);
  console.log(`${selected.length} surfaces, ${jobs.length} captures, concurrency ${concurrency}`);
  let done = 0;
  const manifest = await pool(jobs, concurrency, async (job) => {
    const entry = await capture(browser, job);
    done += 1;
    if (done % 10 === 0 || entry.status !== 'captured') {
      console.log(`${done}/${jobs.length} ${entry.status.slice(0, 12)} ${entry.file}`);
    }
    return entry;
  });
  await contactSheets(browser, manifest);
  await browser.close();
  server.close();
  await fs.writeFile(
    path.join(outDir, 'manifest.json'),
    JSON.stringify({ label, webRoot: path.relative(rootDir, webRoot), captures: manifest }, null, 2),
  );
  const failed = manifest.filter((m) => m.status !== 'captured');
  const overflow = manifest.filter((m) => m.horizontalOverflow);
  console.log(JSON.stringify({ captures: manifest.length, failed: failed.length, overflow: overflow.length, outDir }, null, 2));
}

// A context closing while a route is still being fulfilled is a harness race,
// not a product failure: ignore exactly those, surface everything else.
process.on('unhandledRejection', (error) => {
  const message = String(error?.message || error);
  if (/already handled|has been closed|Target page, context or browser/i.test(message)) return;
  console.error(error);
  process.exit(1);
});

await main();
