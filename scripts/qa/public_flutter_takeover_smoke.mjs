import { chromium, firefox, request } from 'playwright';
import {
  classifyBrowserFailures,
  parseTakeoverEventDetail,
} from './public_flutter_takeover_smoke_support.mjs';

// Optional SSH SOCKS egress (see open_smoke_ssh_egress.sh): when set, both the
// browsers and the raw HTTP probes leave from the deployment host's trusted IP
// instead of the runner's greylisted datacenter IP. Playwright expects socks5://.
const smokeSocksProxy = (process.env.SMOKE_SOCKS_PROXY || '').trim();
const smokeProxyOption = smokeSocksProxy
  ? { server: smokeSocksProxy.replace(/^socks5h:/, 'socks5:') }
  : undefined;
let smokeApiContext = null;

async function rawFetch(url, init = {}) {
  if (!smokeProxyOption) return fetch(url, init);
  if (!smokeApiContext) smokeApiContext = await request.newContext({ proxy: smokeProxyOption });
  const response = await smokeApiContext.fetch(url, {
    method: init.method ?? 'GET',
    headers: init.headers ?? {},
    maxRedirects: (init.redirect === 'manual' || init.redirect === 'error') ? 0 : 20,
    failOnStatusCode: false,
  });
  const headers = response.headers();
  return {
    status: response.status(),
    headers: { get: (name) => headers[name.toLowerCase()] ?? null },
    text: () => response.text(),
  };
}

const canonicalUrl = requiredUrl('PUBLIC_TAKEOVER_URL');
const missingUrl = requiredUrl('PUBLIC_TAKEOVER_MISSING_URL');
const expectTakeover = booleanFromEnv('EXPECT_PUBLIC_FLUTTER_TAKEOVER', false);
const browserNames = (process.env.PUBLIC_TAKEOVER_BROWSERS || 'chromium,firefox')
  .split(',')
  .map((value) => value.trim().toLowerCase())
  .filter(Boolean);
// Optional WAF bypass header (see smoke_production_web.sh). It is only sent to
// the deployment origin so the secret is never disclosed to third-party hosts
// (e.g. the Cloudflare beacon) that the takeover page may contact.
const smokeBypassToken = (process.env.SMOKE_BYPASS_TOKEN || '').trim();
const targetOrigin = new URL(canonicalUrl).origin;
function bypassHeadersFor(url) {
  if (!smokeBypassToken) return {};
  try {
    return new URL(url, canonicalUrl).origin === targetOrigin
      ? { 'X-Deploy-Smoke': smokeBypassToken }
      : {};
  } catch {
    return {};
  }
}
const browserViewports = [
  { name: 'desktop', viewport: { width: 1440, height: 1000 } },
  { name: 'mobile', viewport: { width: 390, height: 844 } },
];
const defaultBrowserRepetitions = process.env.GITHUB_ACTIONS
  ? 1
  : (expectTakeover ? 2 : 1);
const browserRepetitions = positiveIntegerFromEnv(
  'PUBLIC_TAKEOVER_BROWSER_REPETITIONS',
  defaultBrowserRepetitions,
);
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

function positiveIntegerFromEnv(name, fallback) {
  const value = (process.env[name] || '').trim();
  if (!value) return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1 || parsed > 5) {
    throw new Error(`${name} must be an integer between 1 and 5.`);
  }
  return parsed;
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
  const response = await rawFetch(url, {
    headers: { 'cache-control': 'no-cache', ...bypassHeadersFor(url) },
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
      const asset = await rawFetch(assetUrl, { redirect: 'error', headers: bypassHeadersFor(assetUrl) });
      ensure(asset.status === 200, `${path} returned ${asset.status}`);
      ensure(asset.headers.get('content-type')?.includes('javascript'), `${path} has invalid MIME type`);
    }
    const serviceWorkerUrl = new URL('/flutter_service_worker.js', canonicalUrl).toString();
    const serviceWorker = await rawFetch(serviceWorkerUrl, { headers: bypassHeadersFor(serviceWorkerUrl) });
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

async function verifyBrowser(
  browser,
  browserName,
  viewportName,
  viewport,
  repetition,
) {
  const browserLabel = `${browserName}-${viewportName}-run-${repetition}`;
  const context = await browser.newContext({ viewport });
  const page = await context.newPage();
  if (smokeBypassToken) {
    // Inject the bypass header only for same-origin requests; third-party
    // resources the page loads must never receive the secret token.
    await page.route('**/*', async (route) => {
      const request = route.request();
      let sameOrigin = false;
      try { sameOrigin = new URL(request.url()).origin === targetOrigin; } catch { sameOrigin = false; }
      if (sameOrigin) {
        await route.continue({ headers: { ...request.headers(), 'x-deploy-smoke': smokeBypassToken } });
      } else {
        await route.continue();
      }
    });
  }
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
    ensure(response?.status() === 200, `${browserLabel} canonical URL returned ${response?.status()}`);
    ensure(page.url() === canonicalUrl, `${browserLabel} rewrote canonical URL to ${page.url()}`);

    if (!expectTakeover) {
      ensure(await page.locator('h1').count() > 0, `${browserLabel} SSR page has no H1`);
      ensure(await page.locator('#flutter-host').count() === 0, `${browserLabel} saw Flutter host while takeover disabled`);
      return {
        browser: browserName,
        viewport: viewportName,
        repetition,
        takeover: false,
        consoleErrors,
        externalBeaconCspErrors,
        failedRequests,
      };
    }

    await page.locator('#public-document h1').waitFor();
    ensure(await page.locator('#public-document').evaluate((node) => !node.inert), `${browserLabel} SSR was hidden before readiness`);
    await page.waitForFunction(() => document.documentElement.classList.contains('kubus-takeover-complete'), null, { timeout: 90000 });
    const state = await page.evaluate(() => ({
      events: globalThis.__kubusTakeoverSmokeEvents,
      active: document.documentElement.classList.contains('kubus-takeover-active'),
      complete: document.documentElement.classList.contains('kubus-takeover-complete'),
      ssrHidden: document.querySelector('#public-document')?.getAttribute('aria-hidden'),
      hostHidden: document.querySelector('#flutter-host')?.getAttribute('aria-hidden'),
      marks: Object.fromEntries(performance.getEntriesByType('mark').map((entry) => [entry.name, Math.round(entry.startTime)])),
    }));
    ensure(state.active && state.complete, `${browserLabel} did not activate takeover classes`);
    ensure(state.ssrHidden === 'true', `${browserLabel} left SSR active after readiness`);
    ensure(state.hostHidden === null, `${browserLabel} left Flutter host hidden after readiness`);
    const parsed = state.events.find((event) => event.name === 'kubus:public-entity-route-parsed');
    const ready = state.events.find((event) => event.name === 'kubus:public-entity-ready');
    ensure(parsed, `${browserLabel} did not emit canonical route-parsed`);
    ensure(ready, `${browserLabel} did not emit entity-ready`);
    const parsedDetail = parseTakeoverEventDetail(parsed.detail);
    const readyDetail = parseTakeoverEventDetail(ready.detail);
    ensure(parsedDetail?.id === entityId, `${browserLabel} route-parsed ID did not match requested URL`);
    ensure(parsedDetail?.path === new URL(canonicalUrl).pathname, `${browserLabel} route-parsed path did not match requested URL`);
    ensure(readyDetail?.id === entityId, `${browserLabel} entity-ready ID did not match requested URL`);
    ensure(readyDetail?.path === new URL(canonicalUrl).pathname, `${browserLabel} entity-ready path did not match requested URL`);
    ensure(parsedDetail?.type === readyDetail?.type, `${browserLabel} route-parsed type did not match entity-ready type`);
    ensure(page.url() === canonicalUrl, `${browserLabel} changed URL during takeover`);
    const failures = classifyBrowserFailures({
      consoleErrors,
      failedRequests,
      optionalStandbyProbeUrl,
    });
    ensure(failures.criticalConsoleErrors.length === 0, `${browserLabel} console errors: ${failures.criticalConsoleErrors.join(' | ')}`);
    ensure(failures.criticalFailedRequests.length === 0, `${browserLabel} failed requests: ${JSON.stringify(failures.criticalFailedRequests)}`);
    return {
      browser: browserName,
      viewport: viewportName,
      repetition,
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
  }
}

const rawHttp = await verifyRawHttp();
const browserTypes = { chromium, firefox };
const browserResults = [];
for (const browserName of browserNames) {
  const browserType = browserTypes[browserName];
  ensure(browserType, `Unsupported browser: ${browserName}`);
  const browser = await browserType.launch({
    headless: true,
    ...(smokeProxyOption ? { proxy: smokeProxyOption } : {}),
  });
  try {
    for (const { name, viewport } of browserViewports) {
      for (let repetition = 1; repetition <= browserRepetitions; repetition += 1) {
        browserResults.push(
          await verifyBrowser(
            browser,
            browserName,
            name,
            viewport,
            repetition,
          ),
        );
      }
    }
  } finally {
    await browser.close();
  }
}
if (smokeApiContext) await smokeApiContext.dispose();
console.log(JSON.stringify({
  canonicalUrl,
  expectTakeover,
  browserRepetitions,
  rawHttp,
  browserResults,
}, null, 2));