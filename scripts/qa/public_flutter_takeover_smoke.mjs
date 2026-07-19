import { chromium, firefox } from 'playwright';
import {
  classifyBrowserFailures,
  parseTakeoverEventDetail,
} from './public_flutter_takeover_smoke_support.mjs';

const canonicalUrl = requiredUrl('PUBLIC_TAKEOVER_URL');
const missingUrl = requiredUrl('PUBLIC_TAKEOVER_MISSING_URL');
const expectTakeover = booleanFromEnv('EXPECT_PUBLIC_FLUTTER_TAKEOVER', false);
const browserNames = (process.env.PUBLIC_TAKEOVER_BROWSERS || 'chromium,firefox')
  .split(',')
  .map((value) => value.trim().toLowerCase())
  .filter(Boolean);
const entityId = new URL(canonicalUrl).pathname.split('/').filter(Boolean).at(-1);
const optionalStandbyProbeUrl = optionalUrl('PUBLIC_TAKEOVER_OPTIONAL_STANDBY_URL');

const requiredMarkup = [
  /id=["']public-document["']/,
  /id=["']flutter-host["']/,
  /<script\b[^>]*\bsrc=["']\/public_flutter_takeover\.js["']/,
  /<script\b[^>]*\bsrc=["']\/flutter_bootstrap\.js["']/,
];

function requiredUrl(name) {
  const value = (process.env[name] || '').trim();
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  const parsed = new URL(value);
  if (!['https:', 'http:'].includes(parsed.protocol)) {
    throw new Error(`${name} must use HTTP or HTTPS.`);
  }
  return parsed.toString();
}

function booleanFromEnv(name, fallback) {
  const value = (process.env[name] || '').trim().toLowerCase();
  if (!value) return fallback;
  if (['1', 'true', 'yes', 'on'].includes(value)) return true;
  if (['0', 'false', 'no', 'off'].includes(value)) return false;
  throw new Error(`${name} must be a boolean.`);
}

function optionalUrl(name) {
  const value = (process.env[name] || '').trim();
  if (!value) return null;
  const parsed = new URL(value);
  if (!['https:', 'http:'].includes(parsed.protocol)) {
    throw new Error(`${name} must use HTTP or HTTPS.`);
  }
  return parsed.toString();
}

function ensure(condition, message) {
  if (!condition) throw new Error(message);
}

function containsTakeoverMarkup(html) {
  return requiredMarkup.every((pattern) => pattern.test(html));
}

function isExternalBeaconCspError(message) {
  return message.includes('static.cloudflareinsights.com/beacon.min.js')
    && /content[- ]security[- ]policy/i.test(message);
}

function isExternalBeaconCspFailure(request) {
  return request.url().includes('static.cloudflareinsights.com/beacon.min.js')
    && request.failure()?.errorText === 'csp';
}

async function fetchResponse(url) {
  const response = await fetch(url, {
    headers: { 'cache-control': 'no-cache' },
    redirect: 'manual',
  });
  return { response, body: await response.text() };
}

async function verifyRawHttp() {
  const { response, body } = await fetchResponse(canonicalUrl);
  ensure(response.status === 200, `canonical URL returned ${response.status}`);
  ensure(!response.headers.get('location'), 'canonical URL returned a redirect');
  ensure(response.headers.get('content-type')?.includes('text/html'), 'canonical URL is not HTML');
  ensure(/<h1\b[^>]*>[^<\s][\s\S]*?<\/h1>/i.test(body), 'raw SSR document has no meaningful H1');
  ensure(/<meta\b[^>]*\bname=["']description["'][^>]*\bcontent=["'][^"']+/.test(body), 'raw SSR document has no description');
  ensure(new RegExp(`<link\\b[^>]*\\brel=["']canonical["'][^>]*\\bhref=["']${escapeRegex(canonicalUrl)}["']`).test(body), 'canonical tag does not match requested URL');
  ensure(/application\/ld\+json/.test(body), 'raw SSR document has no JSON-LD');
  ensure(/BreadcrumbList/.test(body), 'raw SSR document has no BreadcrumbList');

  const hasTakeover = containsTakeoverMarkup(body);
  ensure(hasTakeover === expectTakeover, `takeover markup expected=${expectTakeover} actual=${hasTakeover}`);

  const { response: missingResponse, body: missingBody } = await fetchResponse(missingUrl);
  ensure(missingResponse.status === 404, `missing URL returned ${missingResponse.status}`);
  ensure(!containsTakeoverMarkup(missingBody), 'missing URL exposed takeover markup');

  if (expectTakeover) {
    for (const path of ['/public_flutter_takeover.js', '/flutter_bootstrap.js', '/main.dart.js']) {
      const assetUrl = new URL(path, canonicalUrl).toString();
      const asset = await fetch(assetUrl, { redirect: 'error' });
      ensure(asset.status === 200, `${path} returned ${asset.status}`);
      ensure(asset.headers.get('content-type')?.includes('javascript'), `${path} has invalid MIME type`);
    }
    const serviceWorker = await fetch(new URL('/flutter_service_worker.js', canonicalUrl));
    const workerSource = await serviceWorker.text();
    ensure(serviceWorker.status === 200, `service worker returned ${serviceWorker.status}`);
    ensure(/unregister/.test(workerSource), 'service worker is not an unregister tombstone');
    ensure(!/addEventListener\s*\(\s*["']fetch["']/.test(workerSource), 'service worker intercepts fetches');
    ensure(!/RESOURCES\s*=/.test(workerSource), 'service worker has a resource manifest');
  }

  return { status: response.status, cacheControl: response.headers.get('cache-control') };
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function verifyBrowser(browserType, browserName) {
  const browser = await browserType.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
  const page = await context.newPage();
  const consoleErrors = [];
  const externalBeaconCspErrors = [];
  const failedRequests = [];
  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    const text = message.text();
    if (isExternalBeaconCspError(text)) {
      externalBeaconCspErrors.push(text);
      return;
    }
    consoleErrors.push(text);
  });
  page.on('requestfailed', (request) => {
    if (!isExternalBeaconCspFailure(request)) {
      failedRequests.push({ url: request.url(), error: request.failure()?.errorText });
    }
  });
  await page.addInitScript(() => {
    globalThis.__kubusTakeoverSmokeEvents = [];
    for (const name of ['kubus:public-entity-route-parsed', 'kubus:public-entity-ready']) {
      globalThis.addEventListener(name, (event) => {
        globalThis.__kubusTakeoverSmokeEvents.push({ name, detail: event.detail || {} });
      });
    }
  });

  try {
    const response = await page.goto(canonicalUrl, { waitUntil: 'domcontentloaded' });
    ensure(response?.status() === 200, `${browserName} canonical URL returned ${response?.status()}`);
    ensure(page.url() === canonicalUrl, `${browserName} rewrote canonical URL to ${page.url()}`);

    if (!expectTakeover) {
      ensure(await page.locator('h1').count() > 0, `${browserName} SSR page has no H1`);
      ensure(await page.locator('#flutter-host').count() === 0, `${browserName} saw Flutter host while takeover disabled`);
      return {
        browser: browserName,
        takeover: false,
        consoleErrors,
        externalBeaconCspErrors,
        failedRequests,
      };
    }

    await page.locator('#public-document h1').waitFor();
    ensure(await page.locator('#public-document').evaluate((node) => !node.inert), `${browserName} SSR was hidden before readiness`);
    await page.waitForFunction(() => document.documentElement.classList.contains('kubus-takeover-complete'), null, { timeout: 90000 });
    const state = await page.evaluate(() => ({
      events: globalThis.__kubusTakeoverSmokeEvents,
      active: document.documentElement.classList.contains('kubus-takeover-active'),
      complete: document.documentElement.classList.contains('kubus-takeover-complete'),
      ssrHidden: document.querySelector('#public-document')?.getAttribute('aria-hidden'),
      hostHidden: document.querySelector('#flutter-host')?.getAttribute('aria-hidden'),
      marks: Object.fromEntries(performance.getEntriesByType('mark').map((entry) => [entry.name, Math.round(entry.startTime)])),
    }));
    ensure(state.active && state.complete, `${browserName} did not activate takeover classes`);
    ensure(state.ssrHidden === 'true', `${browserName} left SSR active after readiness`);
    ensure(state.hostHidden === null, `${browserName} left Flutter host hidden after readiness`);
    const parsed = state.events.find((event) => event.name === 'kubus:public-entity-route-parsed');
    const ready = state.events.find((event) => event.name === 'kubus:public-entity-ready');
    ensure(parsed, `${browserName} did not emit canonical route-parsed`);
    ensure(ready, `${browserName} did not emit entity-ready`);
    const parsedDetail = parseTakeoverEventDetail(parsed.detail);
    const readyDetail = parseTakeoverEventDetail(ready.detail);
    ensure(parsedDetail?.id === entityId, `${browserName} route-parsed ID did not match requested URL`);
    ensure(parsedDetail?.path === new URL(canonicalUrl).pathname, `${browserName} route-parsed path did not match requested URL`);
    ensure(readyDetail?.id === entityId, `${browserName} entity-ready ID did not match requested URL`);
    ensure(readyDetail?.path === new URL(canonicalUrl).pathname, `${browserName} entity-ready path did not match requested URL`);
    ensure(parsedDetail?.type === readyDetail?.type, `${browserName} route-parsed type did not match entity-ready type`);
    ensure(page.url() === canonicalUrl, `${browserName} changed URL during takeover`);
    const failures = classifyBrowserFailures({
      consoleErrors,
      failedRequests,
      optionalStandbyProbeUrl,
    });
    ensure(failures.criticalConsoleErrors.length === 0, `${browserName} console errors: ${failures.criticalConsoleErrors.join(' | ')}`);
    ensure(failures.criticalFailedRequests.length === 0, `${browserName} failed requests: ${JSON.stringify(failures.criticalFailedRequests)}`);
    return {
      browser: browserName,
      takeover: true,
      marks: state.marks,
      consoleErrors: failures.criticalConsoleErrors,
      externalBeaconCspErrors,
      failedRequests: failures.criticalFailedRequests,
      optionalStandbyConsoleErrors: failures.optionalStandbyConsoleErrors,
      optionalStandbyFailures: failures.optionalStandbyFailures,
    };
  } finally {
    await context.close();
    await browser.close();
  }
}

const rawHttp = await verifyRawHttp();
const browserTypes = { chromium, firefox };
const browserResults = [];
for (const browserName of browserNames) {
  const browserType = browserTypes[browserName];
  ensure(browserType, `Unsupported browser: ${browserName}`);
  browserResults.push(await verifyBrowser(browserType, browserName));
}
console.log(JSON.stringify({ canonicalUrl, expectTakeover, rawHttp, browserResults }, null, 2));
