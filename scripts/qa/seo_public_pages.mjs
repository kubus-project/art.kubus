import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, firefox } from 'playwright';

const baseUrl = (process.env.SEO_PREVIEW_URL || 'http://127.0.0.1:4175').replace(/\/+$/, '');
const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const outputDir = resolve(
  rootDir,
  process.env.QA_ARTIFACT_DIR || 'output/playwright/artifacts/seo-public-pages',
);
const ids = {
  artwork: '11111111-1111-4111-8111-111111111111',
  profile: '22222222-2222-4222-8222-222222222222',
  event: '33333333-3333-4333-8333-333333333333',
};

const publicCases = [
  { name: 'en-artwork', path: `/en/artworks/${ids.artwork}`, lang: 'en', heading: 'River Memory' },
  { name: 'sl-artwork', path: `/sl/umetnine/${ids.artwork}`, lang: 'sl', heading: 'River Memory' },
  { name: 'artist-profile', path: `/en/profiles/${ids.profile}`, lang: 'en', heading: 'Maja Novak' },
  { name: 'event', path: `/en/events/${ids.event}`, lang: 'en', heading: 'Art by the River' },
  { name: 'discovery-hub', path: '/en/artworks', lang: 'en', heading: 'Artwork' },
];

const ensure = (condition, message) => {
  if (!condition) throw new Error(message);
};

async function installPerformanceObservers(page) {
  await page.addInitScript(() => {
    globalThis.__kubusQaMetrics = { cls: 0, lcp: 0 };
    try {
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) globalThis.__kubusQaMetrics.lcp = entry.startTime;
      }).observe({ type: 'largest-contentful-paint', buffered: true });
    } catch (_) {}
    try {
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (!entry.hadRecentInput) globalThis.__kubusQaMetrics.cls += entry.value;
        }
      }).observe({ type: 'layout-shift', buffered: true });
    } catch (_) {}
  });
}

async function validateNoJsPage(browser, browserName, testCase) {
  const context = await browser.newContext({
    javaScriptEnabled: false,
    viewport: { width: 1440, height: 1000 },
    colorScheme: 'light',
  });
  const page = await context.newPage();
  try {
    const response = await page.goto(`${baseUrl}${testCase.path}`, { waitUntil: 'domcontentloaded' });
    ensure(response?.status() === 200, `${testCase.path} returned ${response?.status()}`);
    ensure(await page.locator('html').getAttribute('lang') === testCase.lang, `${testCase.path} has wrong language`);
    ensure((await page.locator('h1').first().textContent())?.includes(testCase.heading), `${testCase.path} has wrong H1`);
    ensure(await page.locator('meta[name="description"]').getAttribute('content'), `${testCase.path} has no description`);
    ensure(await page.locator('script[type="application/ld+json"]').count() >= 1, `${testCase.path} lacks JSON-LD`);
    ensure(await page.locator('flutter-view').count() === 0, `${testCase.path} rendered Flutter with JavaScript disabled`);

    const canonical = await page.locator('link[rel="canonical"]').getAttribute('href');
    ensure(canonical === `${baseUrl}${testCase.path}`, `${testCase.path} has wrong canonical: ${canonical}`);
    ensure(await page.locator('link[rel="alternate"][hreflang="en"]').count() === 1, `${testCase.path} lacks English alternate`);
    ensure(await page.locator('link[rel="alternate"][hreflang="sl"]').count() === 1, `${testCase.path} lacks Slovenian alternate`);
    ensure(await page.locator('a[href]').count() >= 2, `${testCase.path} lacks crawlable links`);

    await page.keyboard.press('Tab');
    ensure(await page.locator('a:focus').count() === 1, `${testCase.path} has no keyboard-focusable first link`);
    await page.screenshot({ path: resolve(outputDir, `${browserName}-${testCase.name}-nojs.png`), fullPage: true });
    return { browser: browserName, mode: 'no-js', route: testCase.path, status: 200, canonical };
  } finally {
    await context.close();
  }
}

async function validateTakeover(browser, browserName, testCase, viewport) {
  const context = await browser.newContext({ viewport, colorScheme: testCase.colorScheme || 'light' });
  const page = await context.newPage();
  await installPerformanceObservers(page);
  const consoleErrors = [];
  const failedRequests = [];
  page.on('console', (message) => {
    if (message.type() === 'error') consoleErrors.push(message.text());
  });
  page.on('requestfailed', (request) => {
    failedRequests.push({ url: request.url(), error: request.failure()?.errorText });
  });
  try {
    const response = await page.goto(`${baseUrl}${testCase.path}`, { waitUntil: 'commit' });
    ensure(response?.status() === 200, `${testCase.path} returned ${response?.status()}`);
    await page.locator('#public-document h1').waitFor();
    ensure(await page.locator('#public-document').evaluate((node) => !node.inert), 'SSR was inert before takeover');
    await page.screenshot({ path: resolve(outputDir, `${browserName}-${testCase.name}-initial.png`) });

    try {
      await page.waitForFunction(
        () => performance.getEntriesByName('flutter_takeover_completed').length === 1,
        null,
        { timeout: 90000 },
      );
    } catch (error) {
      const diagnostics = await page.evaluate(() => ({
        marks: performance.getEntriesByType('mark').map((entry) => entry.name),
        flutterView: Boolean(document.querySelector('flutter-view')),
        hostHidden: document.querySelector('#flutter-host')?.getAttribute('aria-hidden'),
        ssrHidden: document.querySelector('#public-document')?.getAttribute('aria-hidden'),
      }));
      await page.screenshot({ path: resolve(outputDir, `${browserName}-${testCase.name}-stalled.png`) });
      throw new Error(
        `${browserName} ${testCase.path} stalled: ${JSON.stringify({ diagnostics, consoleErrors, failedRequests })}`,
        { cause: error },
      );
    }
    ensure(new URL(page.url()).pathname === testCase.path, `takeover rewrote ${testCase.path} to ${page.url()}`);
    ensure(await page.locator('#public-document').getAttribute('aria-hidden') === 'true', 'SSR remained accessible after takeover');
    ensure(await page.locator('#flutter-host').getAttribute('aria-hidden') === null, 'Flutter host stayed hidden');
    const marks = await page.evaluate(() => Object.fromEntries(
      performance.getEntriesByType('mark').map((entry) => [entry.name, Math.round(entry.startTime)]),
    ));
    const performanceMetrics = await page.evaluate(() => ({
      fcp: Math.round(performance.getEntriesByName('first-contentful-paint')[0]?.startTime || 0),
      lcp: Math.round(globalThis.__kubusQaMetrics?.lcp || 0),
      cls: globalThis.__kubusQaMetrics?.cls || 0,
    }));
    ensure(marks.public_entity_ready > marks.public_entity_route_parsed, 'entity readiness preceded route parsing');
    await page.screenshot({ path: resolve(outputDir, `${browserName}-${testCase.name}-ready.png`) });
    return { browser: browserName, mode: 'takeover', route: testCase.path, status: 200, marks, performanceMetrics, consoleErrors };
  } finally {
    await context.close();
  }
}

async function validateFailureFallback(browser) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
  const page = await context.newPage();
  await installPerformanceObservers(page);
  await page.route('**/main.dart.js', (route) => route.abort('failed'));
  try {
    const path = `/en/artworks/${ids.artwork}`;
    const response = await page.goto(`${baseUrl}${path}`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1000);
    ensure(response?.status() === 200, 'bundle failure changed the public status');
    ensure(await page.locator('#public-document h1').textContent() === 'River Memory', 'bundle failure lost the SSR entity');
    ensure(await page.locator('#public-document').getAttribute('aria-hidden') === null, 'bundle failure hid SSR');
    ensure(await page.locator('#flutter-host').getAttribute('aria-hidden') === 'true', 'bundle failure exposed Flutter host');
    const marks = await page.evaluate(() => performance.getEntriesByType('mark').map((entry) => entry.name));
    ensure(marks.includes('flutter_takeover_failed'), 'bundle failure was not diagnosed');
    await page.screenshot({ path: resolve(outputDir, 'chromium-bundle-failure.png'), fullPage: true });
    return { browser: 'chromium', mode: 'bundle-failure', route: path, status: 200, marks };
  } finally {
    await context.close();
  }
}

async function validateSlowTakeover(browser) {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, colorScheme: 'dark' });
  const page = await context.newPage();
  await installPerformanceObservers(page);
  await page.route('**/main.dart.js', async (route) => {
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 3000));
    await route.continue();
  });
  try {
    const path = `/sl/umetnine/${ids.artwork}`;
    await page.goto(`${baseUrl}${path}`, { waitUntil: 'commit' });
    await page.locator('#public-document h1').waitFor();
    await page.waitForTimeout(750);
    ensure(await page.locator('#public-document').evaluate((node) => !node.inert), 'slow bundle hid SSR while loading');
    await page.screenshot({ path: resolve(outputDir, 'chromium-slow-midload.png') });
    await page.waitForFunction(
      () => performance.getEntriesByName('flutter_takeover_completed').length === 1,
      null,
      { timeout: 90000 },
    );
    const marks = await page.evaluate(() => Object.fromEntries(
      performance.getEntriesByType('mark').map((entry) => [entry.name, Math.round(entry.startTime)]),
    ));
    const performanceMetrics = await page.evaluate(() => ({
      fcp: Math.round(performance.getEntriesByName('first-contentful-paint')[0]?.startTime || 0),
      lcp: Math.round(globalThis.__kubusQaMetrics?.lcp || 0),
      cls: globalThis.__kubusQaMetrics?.cls || 0,
    }));
    await page.screenshot({ path: resolve(outputDir, 'chromium-slow-ready.png') });
    return { browser: 'chromium', mode: 'slow-takeover', route: path, status: 200, marks, performanceMetrics };
  } finally {
    await context.close();
  }
}

async function validateBrowser(browserType, browserName) {
  const browser = await browserType.launch({ headless: true });
  try {
    const results = [];
    for (const testCase of publicCases) {
      results.push(await validateNoJsPage(browser, browserName, testCase));
    }
    results.push(await validateTakeover(
      browser,
      browserName,
      { name: 'en-artwork-desktop', path: `/en/artworks/${ids.artwork}`, colorScheme: 'light' },
      { width: 1440, height: 1000 },
    ));
    results.push(await validateTakeover(
      browser,
      browserName,
      { name: 'sl-artwork-mobile', path: `/sl/umetnine/${ids.artwork}`, colorScheme: 'dark' },
      { width: 390, height: 844 },
    ));

    const notFound = await browser.newPage({ javaScriptEnabled: false });
    const notFoundResponse = await notFound.goto(`${baseUrl}/en/not-a-real/public-page`);
    ensure(notFoundResponse?.status() === 404, `custom 404 returned ${notFoundResponse?.status()}`);
    ensure(await notFound.locator('meta[name="robots"]').getAttribute('content') === 'noindex, follow', 'custom 404 is indexable');
    await notFound.close();
    return results;
  } finally {
    await browser.close();
  }
}

await mkdir(outputDir, { recursive: true });
const requestedBrowsers = new Set(
  (process.env.SEO_QA_BROWSERS || 'chromium,firefox')
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean),
);
const results = [];
if (requestedBrowsers.has('chromium')) {
  results.push(...await validateBrowser(chromium, 'chromium'));
  const resilienceBrowser = await chromium.launch({ headless: true });
  try {
    results.push(
      await validateFailureFallback(resilienceBrowser),
      await validateSlowTakeover(resilienceBrowser),
    );
  } finally {
    await resilienceBrowser.close();
  }
}
if (requestedBrowsers.has('firefox')) {
  results.push(...await validateBrowser(firefox, 'firefox'));
}
await writeFile(
  resolve(outputDir, 'report.json'),
  `${JSON.stringify({ baseUrl, generatedAt: new Date().toISOString(), results }, null, 2)}\n`,
);
console.log(`SEO browser validation passed. Artifacts: ${outputDir}`);
