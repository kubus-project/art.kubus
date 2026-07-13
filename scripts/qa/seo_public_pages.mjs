import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, firefox } from 'playwright';

const baseUrl = (process.env.SEO_PREVIEW_URL || 'http://127.0.0.1:4175').replace(/\/+$/, '');
const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const outputDir = resolve(rootDir, process.env.QA_ARTIFACT_DIR || 'output/playwright/artifacts/seo-public-pages');
const ids = {
  artwork: '11111111-1111-4111-8111-111111111111',
  profile: '22222222-2222-4222-8222-222222222222',
  event: '33333333-3333-4333-8333-333333333333',
};

const publicCases = [
  { name: 'en-artwork-desktop', path: `/en/artworks/${ids.artwork}`, lang: 'en', heading: 'River Memory' },
  { name: 'sl-artwork-desktop', path: `/sl/umetnine/${ids.artwork}`, lang: 'sl', heading: 'River Memory' },
  { name: 'artist-profile', path: `/en/profiles/${ids.profile}`, lang: 'en', heading: 'Maja Novak' },
  { name: 'event', path: `/en/events/${ids.event}`, lang: 'en', heading: 'Art by the River' },
  { name: 'discovery-hub', path: '/en/artworks', lang: 'en', heading: 'Artwork' },
];

const ensure = (condition, message) => {
  if (!condition) throw new Error(message);
};

async function validatePublicPage(page, browserName, testCase, { screenshot = true } = {}) {
  const consoleErrors = [];
  const pageErrors = [];
  page.on('console', (message) => {
    if (message.type() === 'error') consoleErrors.push(message.text());
  });
  page.on('pageerror', (error) => pageErrors.push(error.message));

  const response = await page.goto(`${baseUrl}${testCase.path}`, { waitUntil: 'networkidle' });
  ensure(response?.status() === 200, `${testCase.path} returned ${response?.status()}`);
  ensure(await page.locator('html').getAttribute('lang') === testCase.lang, `${testCase.path} has wrong language`);
  ensure((await page.locator('h1').first().textContent())?.includes(testCase.heading), `${testCase.path} has wrong H1`);
  ensure(await page.locator('meta[name="description"]').getAttribute('content'), `${testCase.path} has no description`);

  const canonical = await page.locator('link[rel="canonical"]').getAttribute('href');
  ensure(canonical === `${baseUrl}${testCase.path}`, `${testCase.path} has wrong canonical: ${canonical}`);
  ensure(await page.locator('link[rel="alternate"][hreflang="en"]').count() === 1, `${testCase.path} lacks English alternate`);
  ensure(await page.locator('link[rel="alternate"][hreflang="sl"]').count() === 1, `${testCase.path} lacks Slovenian alternate`);
  ensure(await page.locator('a[href]').count() >= 2, `${testCase.path} lacks crawlable links`);
  ensure(await page.locator('script[src]').count() === 0, `${testCase.path} downloaded application JavaScript`);
  ensure((await page.evaluate(() => performance.getEntriesByType('resource').map((entry) => entry.name))).every((url) => !/flutter|main\.dart|maplibre/i.test(url)), `${testCase.path} loaded Flutter or MapLibre`);

  const imageUrl = await page.locator('meta[property="og:image"]').getAttribute('content');
  const imageResponse = await page.request.get(imageUrl);
  ensure(imageResponse.ok(), `${testCase.path} social image returned ${imageResponse.status()}`);

  await page.keyboard.press('Tab');
  ensure(await page.evaluate(() => document.activeElement?.tagName === 'A'), `${testCase.path} has no keyboard-focusable first link`);
  ensure(consoleErrors.length === 0, `${testCase.path} console errors: ${consoleErrors.join(' | ')}`);
  ensure(pageErrors.length === 0, `${testCase.path} page errors: ${pageErrors.join(' | ')}`);

  if (screenshot) await page.screenshot({ path: resolve(outputDir, `${browserName}-${testCase.name}.png`), fullPage: true });
  return { browser: browserName, route: testCase.path, status: response.status(), canonical, consoleErrors, pageErrors };
}

async function validateBrowser(browserType, browserName) {
  const browser = await browserType.launch({ headless: true });
  const results = [];
  try {
    for (const testCase of publicCases) {
      const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, colorScheme: 'light' });
      results.push(await validatePublicPage(page, browserName, testCase, { screenshot: browserName === 'chromium' || testCase.name === 'en-artwork-desktop' }));
      await page.close();
    }

    const mobile = await browser.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
    results.push(await validatePublicPage(mobile, browserName, {
      name: 'en-artwork-mobile', path: `/en/artworks/${ids.artwork}`, lang: 'en', heading: 'River Memory',
    }, { screenshot: browserName === 'chromium' }));
    ensure(await mobile.locator('body').evaluate((body) => body.scrollWidth <= window.innerWidth), 'mobile artwork overflows horizontally');
    await mobile.close();

    const notFound = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    const notFoundResponse = await notFound.goto(`${baseUrl}/en/not-a-real/public-page`, { waitUntil: 'networkidle' });
    ensure(notFoundResponse?.status() === 404, `custom 404 returned ${notFoundResponse?.status()}`);
    ensure((await notFound.locator('h1').textContent())?.includes('could not be found'), 'custom 404 has wrong heading');
    ensure(await notFound.locator('meta[name="robots"]').getAttribute('content') === 'noindex, follow', 'custom 404 is indexable');
    await notFound.screenshot({ path: resolve(outputDir, `${browserName}-404.png`), fullPage: true });
    await notFound.close();

    const transition = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    await transition.route('**/api/artworks/**', async (route) => {
      const requestUrl = new URL(route.request().url());
      if (requestUrl.pathname.endsWith('/comments')) {
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ comments: [] }) });
      }
      if (requestUrl.pathname.endsWith(`/${ids.artwork}`) && route.request().method() === 'GET') {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            artwork: {
              id: ids.artwork,
              title: 'River Memory',
              artist: 'Maja Novak',
              description: 'A public installation tracing the changing relationship between the Ljubljanica river, its neighborhoods and the shared memory of the city.',
              imageUrl: `${baseUrl}/images/social-preview-default.webp`,
              latitude: 46.05,
              longitude: 14.5,
              isPublic: true,
              isActive: true,
              createdAt: '2026-07-12T10:30:00.000Z',
              updatedAt: '2026-07-12T10:30:00.000Z',
              category: 'Public art',
            },
          }),
        });
      }
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ success: true }) });
    });
    await transition.goto(`${baseUrl}/en/artworks/${ids.artwork}`, { waitUntil: 'networkidle' });
    await transition.getByRole('link', { name: 'Open in art.kubus' }).click();
    await transition.locator('flutter-view').waitFor({ state: 'attached', timeout: 60000 });
    await transition.waitForURL((url) => url.pathname.endsWith(`/a/${ids.artwork}`));
    // Flutter semantics remains disabled by design, so CanvasKit text is not a
    // DOM locator. Give the routed detail view time to paint before capture.
    await transition.waitForTimeout(5000);
    const resourceUrls = await transition.evaluate(() => performance.getEntriesByType('resource').map((entry) => entry.name));
    ensure(resourceUrls.some((url) => /main\.dart\.js/.test(url)), 'Flutter bundle did not load after app handoff');
    await transition.screenshot({ path: resolve(outputDir, `${browserName}-flutter-handoff.png`), fullPage: true });
    results.push({ browser: browserName, route: `/app/a/${ids.artwork}`, status: 200, flutterLoaded: true });
    await transition.close();
  } finally {
    await browser.close();
  }
  return results;
}

await mkdir(outputDir, { recursive: true });
const results = [
  ...(await validateBrowser(chromium, 'chromium')),
  ...(await validateBrowser(firefox, 'firefox')),
];
await writeFile(resolve(outputDir, 'report.json'), `${JSON.stringify({ baseUrl, generatedAt: new Date().toISOString(), results }, null, 2)}\n`);
console.log(`SEO browser validation passed. Artifacts: ${outputDir}`);
