import { mkdir, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, firefox } from 'playwright';

const baseUrl = (process.env.SEO_PREVIEW_URL || 'http://127.0.0.1:4177')
  .replace(/\/+$/, '');
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const outputDir = resolve(
  repoRoot,
  process.env.QA_ARTIFACT_DIR || 'output/playwright/wave2b',
);
const ids = {
  artwork: '11111111-1111-4111-8111-111111111111',
  artist: '22222222-2222-4222-8222-222222222222',
  institution: process.env.PUBLIC_INSTITUTION_FIXTURE_ID ||
    '99999999-9999-4999-8999-999999999999',
  event: '33333333-3333-4333-8333-333333333333',
  exhibition: '44444444-4444-4444-8444-444444444444',
};
const artworkCases = [
  { locale: 'en', path: `/en/artworks/${ids.artwork}` },
  { locale: 'sl', path: `/sl/umetnine/${ids.artwork}` },
];
const productCases = [
  { name: 'artist-profile', path: `/en/profiles/${ids.artist}` },
  { name: 'institution-profile', path: `/en/profiles/${ids.institution}` },
  { name: 'event', path: `/en/events/${ids.event}` },
  { name: 'exhibition', path: `/en/exhibitions/${ids.exhibition}` },
];
const widths = [390, 1440];
const themes = ['light', 'dark'];
const results = [];

function ensure(condition, message) {
  if (!condition) throw new Error(message);
}

function slug(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function screenshotName(...parts) {
  return resolve(outputDir, `${parts.map(slug).join('-')}.png`);
}

function chromiumExecutable() {
  const configured = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE;
  if (configured && existsSync(configured)) return configured;
  const systemChrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  return existsSync(systemChrome) ? systemChrome : undefined;
}

async function openBrowser(browserName, browserType) {
  const executablePath = browserName === 'chromium'
    ? chromiumExecutable()
    : undefined;
  return browserType.launch({
    headless: true,
    ...(executablePath ? { executablePath } : {}),
  });
}

async function captureSsr(browser, browserName, testCase, viewport, colorScheme) {
  const context = await browser.newContext({
    javaScriptEnabled: false,
    viewport,
    colorScheme,
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  try {
    const response = await page.goto(`${baseUrl}${testCase.path}`, {
      waitUntil: 'domcontentloaded',
    });
    ensure(response?.status() === 200, `${testCase.path} SSR returned ${response?.status()}`);
    await page.locator('#public-document h1').waitFor();
    ensure(await page.locator('flutter-view').count() === 0, 'JavaScript-disabled SSR mounted Flutter');
    const canonical = await page.locator('link[rel="canonical"]').getAttribute('href');
    ensure(canonical === `${baseUrl}${testCase.path}`, `wrong canonical for ${testCase.path}: ${canonical}`);
    await page.keyboard.press('Tab');
    const focusedLink = await page.locator('a:focus').count();
    ensure(focusedLink > 0, `SSR keyboard focus did not reach a link for ${testCase.path}`);
    await page.screenshot({
      path: screenshotName(testCase.name || `artwork-${testCase.locale}`, viewport.width, colorScheme, 'ssr', browserName),
    });
    return {
      browser: browserName,
      route: testCase.path,
      state: 'ssr-no-js',
      viewport,
      theme: colorScheme,
      canonical,
      keyboardFocus: true,
    };
  } finally {
    await context.close();
  }
}

async function waitForExactTakeover(page, testCase) {
  await page.waitForFunction(
    () => performance.getEntriesByName('flutter_takeover_completed').length === 1,
    null,
    { timeout: 90000 },
  );
  ensure(new URL(page.url()).pathname === testCase.path, `takeover changed the canonical path for ${testCase.path}`);
  ensure(
    await page.locator('#public-document').getAttribute('aria-hidden') === 'true',
    `SSR accessibility ownership was not released for ${testCase.path}`,
  );
  ensure(
    await page.locator('#public-document').evaluate((node) => node.inert),
    `SSR remained keyboard-interactive after Flutter takeover for ${testCase.path}`,
  );
  ensure(
    await page.locator('#flutter-host').getAttribute('aria-hidden') === null,
    `Flutter remained hidden after takeover for ${testCase.path}`,
  );
}

async function verifyFlutterKeyboard(page) {
  let placeholderFocused = false;
  for (let attempt = 0; attempt < 16; attempt += 1) {
    await page.keyboard.press('Tab');
    placeholderFocused = await page.evaluate(
      () => document.activeElement?.matches('flt-semantics-placeholder') === true,
    );
    if (placeholderFocused) break;
  }
  ensure(placeholderFocused, 'keyboard could not focus Flutter accessibility entry');

  const entryFocus = await page.evaluate(() => {
    const element = document.activeElement;
    const style = getComputedStyle(element);
    return {
      label: element?.getAttribute('aria-label'),
      outlineWidth: Number.parseFloat(style.outlineWidth) || 0,
      outlineStyle: style.outlineStyle,
    };
  });
  ensure(entryFocus.label === 'Enable accessibility', 'Flutter keyboard entry has no clear label');
  ensure(entryFocus.outlineWidth > 0 && entryFocus.outlineStyle !== 'none', 'Flutter keyboard entry focus is not visible');

  await page.keyboard.press('Enter');
  await page.waitForFunction(
    () => document.querySelectorAll('flt-semantics-host flt-semantics').length > 0,
  );

  let focusedControl = null;
  for (let attempt = 0; attempt < 12; attempt += 1) {
    await page.keyboard.press('Tab');
    focusedControl = await page.evaluate(() => {
      const element = document.activeElement;
      if (element?.tagName !== 'FLT-SEMANTICS' || element.getAttribute('role') !== 'button') {
        return null;
      }
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return {
        label: element.textContent?.trim() || element.getAttribute('aria-label') || null,
        x: Math.round(rect.x),
        y: Math.round(rect.y),
        width: Math.round(rect.width),
        height: Math.round(rect.height),
        outlineWidth: Number.parseFloat(style.outlineWidth) || 0,
        outlineStyle: style.outlineStyle,
      };
    });
    if (focusedControl) break;
  }
  ensure(focusedControl, 'keyboard did not reach a Flutter entity action');
  ensure(focusedControl.width > 0 && focusedControl.height > 0, 'focused Flutter action has no visible bounds');
  ensure(
    focusedControl.outlineWidth > 0 && focusedControl.outlineStyle !== 'none',
    'Flutter entity action focus is not visible',
  );

  return {
    ssrBecameInert: true,
    accessibilityEntry: entryFocus,
    semanticControl: focusedControl,
  };
}

async function installProfileApiFixture(page) {
  await page.route('**/api/profiles/*', async (route) => {
    const id = new URL(route.request().url()).pathname.split('/').at(-1);
    const institution = id === ids.institution;
    if (id !== ids.artist && !institution) {
      await route.continue();
      return;
    }
    const displayName = institution ? 'Ljubljana City Museum' : 'Maja Novak';
    const username = institution ? 'ljubljana-city-museum' : 'maja-novak';
    const record = {
      id,
      walletAddress: id,
      wallet_address: id,
      username,
      name: displayName,
      displayName,
      display_name: displayName,
      bio: institution
        ? 'A public cultural institution presenting visual art and local history in Ljubljana.'
        : 'Maja Novak is an artist working with public space, ecology and participatory archives across Slovenia.',
      avatar: `${baseUrl}/images/social-preview-default.webp?entity=${username}`,
      avatarUrl: `${baseUrl}/images/social-preview-default.webp?entity=${username}`,
      avatar_url: `${baseUrl}/images/social-preview-default.webp?entity=${username}`,
      coverImage: `${baseUrl}/images/social-preview-default.webp?entity=${username}-cover`,
      cover_image_url: `${baseUrl}/images/social-preview-default.webp?entity=${username}-cover`,
      isArtist: !institution,
      is_artist: !institution,
      isInstitution: institution,
      is_institution: institution,
      isActive: true,
      is_active: true,
      publicWorkCount: institution ? 12 : 4,
      public_work_count: institution ? 12 : 4,
      createdAt: '2026-01-10T10:00:00.000Z',
      updatedAt: '2026-09-22T10:00:00.000Z',
      preferences: { privacy: 'public' },
    };
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, data: record }),
    });
  });
}

async function layoutMetrics(page) {
  return page.evaluate(() => {
    const flutterView = document.querySelector('flutter-view');
    const bounds = flutterView?.getBoundingClientRect();
    const viewportWidth = document.documentElement.clientWidth;
    const documentWidth = document.documentElement.scrollWidth;
    const bodyWidth = document.body.scrollWidth;
    const overflowOffenders = documentWidth > viewportWidth || bodyWidth > viewportWidth
      ? [...document.body.querySelectorAll('*')]
        .map((element) => {
          const rect = element.getBoundingClientRect();
          return {
            tag: element.tagName.toLowerCase(),
            id: element.id || null,
            className: typeof element.className === 'string'
              ? element.className.slice(0, 100)
              : null,
            left: Math.round(rect.left),
            right: Math.round(rect.right),
            width: Math.round(rect.width),
            scrollWidth: element.scrollWidth,
            clientWidth: element.clientWidth,
          };
        })
        .filter((item) => item.right > viewportWidth + 1 || item.left < -1)
        .slice(0, 12)
      : [];
    return {
      innerWidth: window.innerWidth,
      documentWidth,
      bodyWidth,
      flutterLeft: bounds ? Math.round(bounds.left) : null,
      flutterRight: bounds ? Math.round(bounds.right) : null,
      reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
      overflowOffenders,
    };
  });
}

async function captureTakeover(browser, browserName, testCase, viewport, colorScheme) {
  const context = await browser.newContext({
    viewport,
    colorScheme,
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  if (testCase.path.includes('/profiles/')) {
    await installProfileApiFixture(page);
  }
  let releaseMain;
  let mainRequested;
  const mainGate = new Promise((resolveGate) => { releaseMain = resolveGate; });
  const mainSeen = new Promise((resolveSeen) => { mainRequested = resolveSeen; });
  let mainWasRequested = false;
  await page.route('**/main.dart.js', async (route) => {
    mainWasRequested = true;
    mainRequested();
    await mainGate;
    await route.continue();
  });

  try {
    const response = await page.goto(`${baseUrl}${testCase.path}`, { waitUntil: 'domcontentloaded' });
    ensure(response?.status() === 200, `${testCase.path} returned ${response?.status()}`);
    await page.locator('#public-document h1').waitFor();
    await Promise.race([
      mainSeen,
      new Promise((_, reject) => setTimeout(() => reject(new Error('Flutter entry bundle was not requested')), 15000)),
    ]);
    ensure(mainWasRequested, `Flutter entry bundle did not request for ${testCase.path}`);
    ensure(await page.locator('#public-document').evaluate((node) => !node.inert), 'SSR became inert before takeover');
    const initial = await layoutMetrics(page);
    await page.screenshot({ path: screenshotName(testCase.name || `artwork-${testCase.locale}`, viewport.width, colorScheme, 'loading', browserName) });

    releaseMain();
    await waitForExactTakeover(page, testCase);
    await page.waitForTimeout(250);
    const metrics = await layoutMetrics(page);
    ensure(metrics.documentWidth <= metrics.innerWidth, `document overflow ${metrics.documentWidth}px at ${metrics.innerWidth}px for ${testCase.path}`);
    ensure(metrics.bodyWidth <= metrics.innerWidth, `body overflow ${metrics.bodyWidth}px at ${metrics.innerWidth}px for ${testCase.path}`);
    ensure(metrics.flutterLeft === 0 && metrics.flutterRight === metrics.innerWidth, `Flutter viewport does not match CSS viewport for ${testCase.path}`);
    ensure(metrics.reducedMotion, 'reduced-motion preference was not applied');
    await page.screenshot({ path: screenshotName(testCase.name || `artwork-${testCase.locale}`, viewport.width, colorScheme, 'flutter', browserName) });
    let keyboard = null;
    if (testCase.path === artworkCases[0].path && viewport.width === 390 && colorScheme === 'light') {
      keyboard = await verifyFlutterKeyboard(page);
      await page.screenshot({
        path: screenshotName('artwork-en', 390, colorScheme, 'flutter-keyboard-focused', browserName),
      });
    }
    return {
      browser: browserName,
      route: testCase.path,
      state: 'flutter-takeover',
      viewport,
      theme: colorScheme,
      initial,
      metrics,
      ...(keyboard ? { keyboard } : {}),
    };
  } finally {
    releaseMain();
    await context.close();
  }
}

function escapeHtml(value) {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}

async function installLongArtworkFixture(page, locale) {
  const path = locale === 'sl'
    ? `/sl/umetnine/${ids.artwork}`
    : `/en/artworks/${ids.artwork}`;
  const title = locale === 'sl'
    ? 'Dolgo slovensko ime javnega umetniškega dela za preverjanje postavitve'
    : 'A Long Public Artwork Title for Responsive Layout Verification';
  const artist = locale === 'sl'
    ? 'Maja Novak in sodelavci iz lokalnega umetniškega arhiva'
    : 'Maja Novak and collaborators from the public art archive';
  const description = locale === 'sl'
    ? 'Javno umetniško delo povezuje rečni prostor, soseske in skupni spomin mesta. Ta daljši opis preverja, da se besedilo pri ozkem prikazu prelomi in ostane berljivo.'
    : 'This public artwork connects the river, nearby neighborhoods, and shared city memory. This longer description checks that text wraps cleanly and remains readable at narrow viewport widths.';
  const originalDescription = 'A public installation tracing the changing relationship between the Ljubljanica river, its neighborhoods and the shared memory of the city.';

  await page.route(`**${path}`, async (route) => {
    const response = await route.fetch();
    let html = await response.text();
    const bootstrapPattern = /(<script id="kubus-public-entity-bootstrap" type="application\/json">)([\s\S]*?)(<\/script>)/;
    const bootstrapMatch = html.match(bootstrapPattern);
    ensure(bootstrapMatch, 'long-title fixture did not find the safe bootstrap payload');
    const bootstrap = JSON.parse(bootstrapMatch[2]);
    bootstrap.presentation.title = title;
    bootstrap.presentation.description = description;
    if (bootstrap.presentation.authorship) bootstrap.presentation.authorship.name = artist;
    const safePayload = JSON.stringify(bootstrap).replaceAll('<', '\\u003c');
    html = html.replace(bootstrapPattern, `$1${safePayload}$3`);
    html = html.replace(/(<h1\b[^>]*>)[\s\S]*?(<\/h1>)/, `$1${escapeHtml(title)}$2`);
    html = html.replaceAll('River Memory', escapeHtml(title));
    html = html.replaceAll('Maja Novak', escapeHtml(artist));
    html = html.replaceAll(originalDescription, escapeHtml(description));
    const headers = { ...response.headers() };
    delete headers['content-length'];
    delete headers['content-encoding'];
    await route.fulfill({ status: response.status(), headers, body: html });
  });
  await page.route(`**/api/artworks/${ids.artwork}`, async (route) => {
    const response = await route.fetch();
    const payload = await response.json();
    if (payload.data && typeof payload.data === 'object') {
      Object.assign(payload.data, {
        title,
        artist,
        artist_name: artist,
        description,
      });
    }
    await route.fulfill({
      status: response.status(),
      contentType: 'application/json',
      body: JSON.stringify(payload),
    });
  });

  return { path, title, artist };
}

async function validateResponsiveArtwork(browser, browserName, locale) {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    colorScheme: locale === 'sl' ? 'dark' : 'light',
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  try {
    const fixture = await installLongArtworkFixture(page, locale);
    const response = await page.goto(`${baseUrl}${fixture.path}`, { waitUntil: 'domcontentloaded' });
    ensure(response?.status() === 200, `long-text fixture returned ${response?.status()}`);
    await page.locator('#public-document h1').waitFor();
    ensure((await page.locator('#public-document h1').textContent())?.includes(fixture.title), 'SSR long title fixture was not installed');
    await page.screenshot({ path: screenshotName(`artwork-${locale}-long-text`, 390, 'ssr', browserName) });
    const testCase = { path: fixture.path };
    await waitForExactTakeover(page, testCase);

    const viewportResults = [];
    for (const width of [320, 360, 390, 430]) {
      await page.setViewportSize({ width, height: 844 });
      await page.waitForFunction(
        (expectedWidth) => {
          const view = document.querySelector('flutter-view');
          const bounds = view?.getBoundingClientRect();
          return window.innerWidth === expectedWidth && bounds &&
            Math.round(bounds.left) === 0 && Math.round(bounds.right) === expectedWidth;
        },
        width,
        { timeout: 5000 },
      );
      const metrics = await layoutMetrics(page);
      ensure(metrics.documentWidth <= width, `long-text document overflows ${width}px viewport: ${JSON.stringify(metrics)}`);
      ensure(metrics.bodyWidth <= width, `long-text body overflows ${width}px viewport: ${JSON.stringify(metrics)}`);
      ensure(metrics.flutterLeft === 0 && metrics.flutterRight === width, `Flutter view does not fit ${width}px viewport: ${JSON.stringify(metrics)}`);
      await page.screenshot({ path: screenshotName(`artwork-${locale}-long-text`, width, 'flutter', browserName) });
      viewportResults.push({ width, metrics });
    }
    return {
      browser: browserName,
      route: fixture.path,
      state: 'long-text-responsive',
      locale,
      title: fixture.title,
      artist: fixture.artist,
      viewports: viewportResults,
    };
  } finally {
    await context.close();
  }
}

async function validateFailureStates(browser, browserName) {
  const slowContext = await browser.newContext({
    viewport: { width: 390, height: 844 },
    colorScheme: 'dark',
    reducedMotion: 'reduce',
  });
  const slowPage = await slowContext.newPage();
  await slowPage.route('**/main.dart.js', async (route) => {
    await new Promise((resolveDelay) => setTimeout(resolveDelay, 2400));
    await route.continue();
  });
  try {
    const path = `/sl/umetnine/${ids.artwork}`;
    await slowPage.goto(`${baseUrl}${path}`, { waitUntil: 'commit' });
    await slowPage.locator('#public-document h1').waitFor();
    await slowPage.waitForTimeout(500);
    ensure(await slowPage.locator('#public-document').evaluate((node) => !node.inert), 'slow Flutter load hid usable SSR');
    await slowPage.screenshot({ path: screenshotName('artwork-sl', 390, 'slow-loading-ssr', browserName) });
    await waitForExactTakeover(slowPage, { path });
    await slowPage.screenshot({ path: screenshotName('artwork-sl', 390, 'slow-loading-flutter', browserName) });
  } finally {
    await slowContext.close();
  }

  const failureContext = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    colorScheme: 'light',
    reducedMotion: 'reduce',
  });
  const failurePage = await failureContext.newPage();
  await failurePage.route('**/main.dart.js', (route) => route.abort('failed'));
  try {
    const path = `/en/artworks/${ids.artwork}`;
    const response = await failurePage.goto(`${baseUrl}${path}`, { waitUntil: 'commit' });
    await failurePage.waitForTimeout(1200);
    ensure(
      response?.status() === 200,
      `Flutter bundle failure changed public HTTP status: ${response?.status() ?? 'no navigation response'}`,
    );
    ensure(await failurePage.locator('#public-document').getAttribute('aria-hidden') === null, 'Flutter bundle failure hid SSR');
    ensure(await failurePage.locator('#flutter-host').getAttribute('aria-hidden') === 'true', 'failed Flutter host became visible');
    await failurePage.keyboard.press('Tab');
    ensure(await failurePage.locator('#public-document a:focus').count() > 0, 'SSR lost keyboard navigation after bundle failure');
    await failurePage.screenshot({ path: screenshotName('artwork-en', 1440, 'bundle-failure-ssr', browserName) });
  } finally {
    await failureContext.close();
  }
  return {
    browser: browserName,
    state: 'failure-states',
    slowFlutter: 'SSR remained accessible before exact takeover',
    bundleFailure: 'SSR remained visible and host stayed hidden',
  };
}

async function validateZoom(browser, browserName) {
  const context = await browser.newContext({
    viewport: { width: 195, height: 422 },
    deviceScaleFactor: 2,
    colorScheme: 'light',
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  try {
    const path = `/en/artworks/${ids.artwork}`;
    await page.goto(`${baseUrl}${path}`, { waitUntil: 'commit' });
    await waitForExactTakeover(page, { path });
    const metrics = await layoutMetrics(page);
    ensure(metrics.innerWidth === 195, `200% zoom-effective CSS width was ${metrics.innerWidth}`);
    ensure(metrics.documentWidth <= 195 && metrics.bodyWidth <= 195, `200% zoom-effective layout overflowed: ${JSON.stringify(metrics)}`);
    await page.screenshot({ path: screenshotName('artwork-en', 390, '200-percent-zoom-effective', browserName) });
    return {
      browser: browserName,
      state: 'zoom-effective-width',
      viewport: { width: 195, height: 422, deviceScaleFactor: 2 },
      metrics,
    };
  } finally {
    await context.close();
  }
}

async function runBrowser(browserName, browserType) {
  const browser = await openBrowser(browserName, browserType);
  try {
    for (const testCase of artworkCases) {
      for (const width of widths) {
        for (const colorScheme of themes) {
          const viewport = { width, height: width === 390 ? 844 : 900 };
          results.push(await captureSsr(browser, browserName, testCase, viewport, colorScheme));
          results.push(await captureTakeover(browser, browserName, testCase, viewport, colorScheme));
        }
      }
    }
    for (const testCase of productCases) {
      const viewport = { width: 1440, height: 900 };
      results.push(await captureSsr(browser, browserName, testCase, viewport, 'light'));
      results.push(await captureTakeover(browser, browserName, testCase, viewport, 'light'));
    }
    for (const locale of ['en', 'sl']) {
      results.push(await validateResponsiveArtwork(browser, browserName, locale));
    }
    results.push(await validateFailureStates(browser, browserName));
    results.push(await validateZoom(browser, browserName));
  } finally {
    await browser.close();
  }
}

await mkdir(outputDir, { recursive: true });
const requestedBrowsers = new Set(
  (process.env.WAVE2B_BROWSERS || 'chromium,firefox')
    .split(',')
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean),
);
if (requestedBrowsers.has('chromium')) await runBrowser('chromium', chromium);
if (requestedBrowsers.has('firefox')) await runBrowser('firefox', firefox);

const report = {
  sourceSha: process.env.WAVE2B_SOURCE_SHA || null,
  previewOrigin: baseUrl,
  fixtureScope: 'local public-only demo entities; no production data',
  generatedAt: new Date().toISOString(),
  results,
};
await writeFile(resolve(outputDir, 'visual-matrix.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({ outputDir, cases: results.length, browsers: [...requestedBrowsers] }, null, 2));
