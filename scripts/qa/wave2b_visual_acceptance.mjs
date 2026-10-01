import { mkdir, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';
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
  collectible: '55555555-5555-4555-8555-555555555555',
  post: '66666666-6666-4666-8666-666666666666',
  collection: '77777777-7777-4777-8777-777777777777',
  marker: '88888888-8888-4888-8888-888888888888',
};
const artworkCases = [
  { locale: 'en', path: `/en/artworks/${ids.artwork}` },
  { locale: 'sl', path: `/sl/umetnine/${ids.artwork}` },
];
const productCases = [
  { name: 'artist-profile-en', type: 'profile', path: `/en/profiles/${ids.artist}` },
  { name: 'artist-profile-sl', type: 'profile', path: `/sl/profili/${ids.artist}` },
  { name: 'institution-profile-en', type: 'profile', path: `/en/profiles/${ids.institution}` },
  { name: 'institution-profile-sl', type: 'profile', path: `/sl/profili/${ids.institution}` },
  { name: 'event-en', type: 'event', path: `/en/events/${ids.event}` },
  { name: 'exhibition-en', type: 'exhibition', path: `/en/exhibitions/${ids.exhibition}` },
];
const supportingRouteCases = [
  { name: 'collection-route-smoke', path: `/en/collections/${ids.collection}`, expectedHeading: 'River Works' },
  { name: 'post-route-smoke', path: `/en/posts/${ids.post}`, expectedHeading: 'Maja Novak' },
  { name: 'marker-route-smoke', path: `/en/map/${ids.marker}`, expectedHeading: 'River Memory' },
  { name: 'collectible-route-smoke', path: `/en/collectibles/${ids.collectible}`, expectedHeading: 'River Memory Edition' },
];
const widths = [390, 1440];
const themes = ['light', 'dark'];
const results = [];

function ensure(condition, message) {
  if (!condition) throw new Error(message);
}

async function focusPublicDocumentLink(page) {
  const focusedLink = '#public-document a:focus, #content a:focus, main a:focus';
  for (let attempt = 0; attempt < 8; attempt += 1) {
    if (await page.locator(focusedLink).count() > 0) return;
    await page.keyboard.press('Tab');
  }
  ensure(false, 'SSR keyboard navigation did not reach a public entity link');
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
    const h1 = page.locator('#public-document h1, #content h1, main h1').first();
    await h1.waitFor({ state: 'visible' });
    if (testCase.expectedHeading) {
      const heading = (await h1.textContent())?.trim() || '';
      ensure(heading.includes(testCase.expectedHeading), `unexpected public heading for ${testCase.path}: ${heading}`);
    }
    ensure(await page.locator('flutter-view').count() === 0, 'JavaScript-disabled SSR mounted Flutter');
    const canonical = await page.locator('link[rel="canonical"]').getAttribute('href');
    ensure(canonical === `${baseUrl}${testCase.path}`, `wrong canonical for ${testCase.path}: ${canonical}`);
    const visualScreenshot = screenshotName(testCase.name || `artwork-${testCase.locale}`, viewport.width, colorScheme, 'ssr', browserName);
    await page.screenshot({
      path: visualScreenshot,
    });
    await focusPublicDocumentLink(page);
    const keyboardScreenshot = screenshotName(testCase.name || `artwork-${testCase.locale}`, viewport.width, colorScheme, 'ssr-keyboard-focused', browserName);
    await page.screenshot({
      path: keyboardScreenshot,
    });
    return {
      browser: browserName,
      route: testCase.path,
      state: 'ssr-no-js',
      viewport,
      theme: colorScheme,
      canonical,
      keyboardFocus: true,
      screenshotFiles: [visualScreenshot, keyboardScreenshot],
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
      if (
        element?.tagName !== 'FLT-SEMANTICS' ||
        !['button', 'switch'].includes(element.getAttribute('role'))
      ) {
        return null;
      }
      const label = (element.getAttribute('aria-label') || element.textContent || '')
        .trim()
        .toLowerCase();
      if (!['like', 'liked', 'save', 'saved', 'comments', 'share', 'show on map', 'navigate'].includes(label)) {
        return null;
      }
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return {
        label,
        role: element.getAttribute('role'),
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

// Keep browser evidence self-contained and away from production APIs. Flutter's
// release artifact has the production API origin baked in, so proxy anonymous
// requests back to the public-only local SSR preview used by this matrix.
async function installLocalPreviewApiProxy(page) {
  await page.route('https://api.kubus.site/**', async (route) => {
    const requested = new URL(route.request().url());
    const localUrl = `${baseUrl}${requested.pathname}${requested.search}`;
    const response = await route.fetch({ url: localUrl });
    await route.fulfill({ response });
  });
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

  await page.route('**/api/stats/user/*', async (route) => {
    const id = new URL(route.request().url()).pathname.split('/').at(-1);
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        success: true,
        data: {
          entityType: 'user',
          entityId: id,
          scope: 'public',
          metrics: ['posts', 'followers', 'following', 'publicStreetArtAdded'],
          counters: {
            posts: 0,
            followers: 0,
            following: 0,
            publicStreetArtAdded: id === ids.artist ? 4 : 12,
          },
          generatedAt: '2026-09-22T10:00:00.000Z',
        },
      }),
    });
  });

  await page.route('**/api/community/posts*', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ success: true, data: [] }),
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
  await installLocalPreviewApiProxy(page);
  if (testCase.path.includes('/profiles/') || testCase.path.includes('/profili/')) {
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
    const loadingScreenshot = screenshotName(testCase.name || `artwork-${testCase.locale}`, viewport.width, colorScheme, 'loading', browserName);
    await page.screenshot({ path: loadingScreenshot });

    releaseMain();
    await waitForExactTakeover(page, testCase);
    await page.waitForTimeout(250);
    const metrics = await layoutMetrics(page);
    ensure(metrics.documentWidth <= metrics.innerWidth, `document overflow ${metrics.documentWidth}px at ${metrics.innerWidth}px for ${testCase.path}`);
    ensure(metrics.bodyWidth <= metrics.innerWidth, `body overflow ${metrics.bodyWidth}px at ${metrics.innerWidth}px for ${testCase.path}`);
    ensure(metrics.flutterLeft === 0 && metrics.flutterRight === metrics.innerWidth, `Flutter viewport does not match CSS viewport for ${testCase.path}`);
    ensure(metrics.reducedMotion, 'reduced-motion preference was not applied');
    const flutterScreenshot = screenshotName(testCase.name || `artwork-${testCase.locale}`, viewport.width, colorScheme, 'flutter', browserName);
    await page.screenshot({ path: flutterScreenshot });
    let keyboard = null;
    let keyboardScreenshot = null;
    if (testCase.path === artworkCases[0].path && viewport.width === 390 && colorScheme === 'light') {
      keyboard = await verifyFlutterKeyboard(page);
      keyboardScreenshot = screenshotName('artwork-en', 390, colorScheme, 'flutter-keyboard-focused', browserName);
      await page.screenshot({
        path: keyboardScreenshot,
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
      screenshotFiles: [
        loadingScreenshot,
        flutterScreenshot,
        ...(keyboardScreenshot ? [keyboardScreenshot] : []),
      ],
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
    const response = await route.fetch({
      url: `${baseUrl}/api/artworks/${ids.artwork}`,
    });
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
    await installLocalPreviewApiProxy(page);
    const fixture = await installLongArtworkFixture(page, locale);
    const response = await page.goto(`${baseUrl}${fixture.path}`, { waitUntil: 'domcontentloaded' });
    ensure(response?.status() === 200, `long-text fixture returned ${response?.status()}`);
    await page.locator('#public-document h1').waitFor();
    ensure((await page.locator('#public-document h1').textContent())?.includes(fixture.title), 'SSR long title fixture was not installed');
    const ssrScreenshot = screenshotName(`artwork-${locale}-long-text`, 390, 'ssr', browserName);
    await page.screenshot({ path: ssrScreenshot });
    const testCase = { path: fixture.path };
    await waitForExactTakeover(page, testCase);

    const viewportResults = [];
    const screenshotFiles = [ssrScreenshot];
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
      const screenshot = screenshotName(`artwork-${locale}-long-text`, width, 'flutter', browserName);
      await page.screenshot({ path: screenshot });
      screenshotFiles.push(screenshot);
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
      screenshotFiles,
    };
  } finally {
    await context.close();
  }
}

async function validateFailureStates(browser, browserName) {
  let slowSsrScreenshot;
  let slowFlutterScreenshot;
  let failureScreenshot;
  const slowContext = await browser.newContext({
    viewport: { width: 390, height: 844 },
    colorScheme: 'dark',
    reducedMotion: 'reduce',
  });
  const slowPage = await slowContext.newPage();
  await installLocalPreviewApiProxy(slowPage);
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
    slowSsrScreenshot = screenshotName('artwork-sl', 390, 'slow-loading-ssr', browserName);
    await slowPage.screenshot({ path: slowSsrScreenshot });
    await waitForExactTakeover(slowPage, { path });
    slowFlutterScreenshot = screenshotName('artwork-sl', 390, 'slow-loading-flutter', browserName);
    await slowPage.screenshot({ path: slowFlutterScreenshot });
  } finally {
    await slowContext.close();
  }

  const failureContext = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    colorScheme: 'light',
    reducedMotion: 'reduce',
  });
  const failurePage = await failureContext.newPage();
  await installLocalPreviewApiProxy(failurePage);
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
    await focusPublicDocumentLink(failurePage);
    failureScreenshot = screenshotName('artwork-en', 1440, 'bundle-failure-ssr', browserName);
    await failurePage.screenshot({ path: failureScreenshot });
  } finally {
    await failureContext.close();
  }
  return {
    browser: browserName,
    state: 'failure-states',
    route: `/en/artworks/${ids.artwork}`,
    slowFlutter: 'SSR remained accessible before exact takeover',
    bundleFailure: 'SSR remained visible and host stayed hidden',
    screenshotFiles: [slowSsrScreenshot, slowFlutterScreenshot, failureScreenshot],
  };
}

async function validateNarrowViewport(browser, browserName) {
  const context = await browser.newContext({
    viewport: { width: 195, height: 422 },
    deviceScaleFactor: 2,
    colorScheme: 'light',
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  try {
    await installLocalPreviewApiProxy(page);
    const path = `/en/artworks/${ids.artwork}`;
    await page.goto(`${baseUrl}${path}`, { waitUntil: 'commit' });
    await waitForExactTakeover(page, { path });
    const metrics = await layoutMetrics(page);
    ensure(metrics.innerWidth === 195, `narrow simulation CSS width was ${metrics.innerWidth}`);
    ensure(metrics.documentWidth <= 195 && metrics.bodyWidth <= 195, `narrow simulation overflowed: ${JSON.stringify(metrics)}`);
    const screenshot = screenshotName('artwork-en', 390, 'narrow-viewport-simulation-not-zoom', browserName);
    await page.screenshot({ path: screenshot });
    return {
      browser: browserName,
      state: 'narrow-css-viewport-simulation-not-browser-zoom',
      route: `/en/artworks/${ids.artwork}`,
      zoomMode: 'viewport-simulation-not-browser-zoom',
      viewport: { width: 195, height: 422, deviceScaleFactor: 2 },
      metrics,
      screenshotFiles: [screenshot],
    };
  } finally {
    await context.close();
  }
}

async function validateRealBrowserZoom(browser, browserName) {
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    colorScheme: 'light',
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  try {
    await installLocalPreviewApiProxy(page);
    const path = `/en/artworks/${ids.artwork}`;
    await page.goto(`${baseUrl}${path}`, { waitUntil: 'commit' });
    await waitForExactTakeover(page, { path });
    const before = await page.evaluate(() => ({
      innerWidth: window.innerWidth,
      devicePixelRatio: window.devicePixelRatio,
      visualViewportScale: window.visualViewport?.scale ?? null,
    }));

    let after = before;
    for (let step = 0; step < 7; step += 1) {
      await page.keyboard.press('Control+Shift+=').catch(() => {});
      await page.waitForTimeout(120);
      after = await page.evaluate(() => ({
        innerWidth: window.innerWidth,
        devicePixelRatio: window.devicePixelRatio,
        visualViewportScale: window.visualViewport?.scale ?? null,
      }));
      if (after.devicePixelRatio >= before.devicePixelRatio * 1.9 ||
          after.innerWidth <= before.innerWidth / 1.9) {
        break;
      }
    }

    const applied = after.devicePixelRatio >= before.devicePixelRatio * 1.9 ||
        after.innerWidth <= before.innerWidth / 1.9;
    if (!applied) {
      return {
        browser: browserName,
        state: 'real-browser-zoom-unverified',
        route: `/en/artworks/${ids.artwork}`,
        zoomMode: 'keyboard-shortcut-attempted',
        reason: 'Browser did not report a 200% page zoom after Ctrl+Plus attempts.',
        before,
        after,
      };
    }

    const metrics = await layoutMetrics(page);
    ensure(metrics.documentWidth <= metrics.innerWidth, `real browser zoom caused document overflow: ${JSON.stringify(metrics)}`);
    ensure(metrics.bodyWidth <= metrics.innerWidth, `real browser zoom caused body overflow: ${JSON.stringify(metrics)}`);
    const screenshot = screenshotName('artwork-en', 'real-browser-200-percent-zoom', browserName);
    await page.screenshot({
      path: screenshot,
      fullPage: true,
    });
    return {
      browser: browserName,
      state: 'real-browser-zoom-passed',
      route: `/en/artworks/${ids.artwork}`,
      zoomMode: 'browser-keyboard-shortcut',
      before,
      after,
      metrics,
      screenshotFiles: [screenshot],
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
      const themesForEntity = testCase.type === 'profile' ? themes : ['light'];
      for (const width of [390, 1440]) {
        const viewport = { width, height: width === 390 ? 844 : 900 };
        for (const colorScheme of themesForEntity) {
          results.push(await captureSsr(browser, browserName, testCase, viewport, colorScheme));
          results.push(await captureTakeover(browser, browserName, testCase, viewport, colorScheme));
        }
      }
    }
    for (const testCase of supportingRouteCases) {
      results.push(await captureSsr(
        browser,
        browserName,
        testCase,
        { width: 390, height: 844 },
        'light',
      ));
    }
    for (const width of [900, 1024, 1280]) {
      const testCase = artworkCases[0];
      const viewport = { width, height: 900 };
      results.push(await captureSsr(browser, browserName, testCase, viewport, 'light'));
      results.push(await captureTakeover(browser, browserName, testCase, viewport, 'light'));
    }
    for (const locale of ['en', 'sl']) {
      results.push(await validateResponsiveArtwork(browser, browserName, locale));
    }
    results.push(await validateFailureStates(browser, browserName));
    results.push(await validateNarrowViewport(browser, browserName));
    results.push(await validateRealBrowserZoom(browser, browserName));
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
  apiEvidencePolicy: 'api.kubus.site requests are proxied to the local public-only preview',
  generatedAt: new Date().toISOString(),
  results: results.map((result) => {
    const pathname = result.route || `/en/artworks/${ids.artwork}`;
    const segments = pathname.split('/').filter(Boolean);
    const entityType = ({
      artworks: 'artwork',
      umetnine: 'artwork',
      profiles: 'profile',
      profili: 'profile',
      events: 'event',
      dogodki: 'event',
      exhibitions: 'exhibition',
      razstave: 'exhibition',
      collections: 'collection',
      zbirke: 'collection',
      posts: 'post',
      objave: 'post',
      map: 'marker',
      collectibles: 'collectible',
    })[segments[1]] || 'artwork';
    const entityId = segments[2] || ids.artwork;
    return {
      ...result,
      sourceSha: process.env.WAVE2B_SOURCE_SHA || null,
      browser: result.browser,
      viewport: result.viewport || { width: 1440, height: 900 },
      theme: result.theme || 'light',
      locale: result.locale || (segments[0] === 'sl' ? 'sl' : 'en'),
      entityType,
      entityId,
      fixtureIdentity: 'synthetic public-only local preview fixture',
      state: result.state,
      javascriptState: result.state === 'ssr-no-js'
        ? 'disabled'
        : result.state === 'failure-states'
          ? 'enabled; bundle delayed or blocked'
          : 'enabled',
      reducedMotion: 'reduce',
      zoomMode: result.zoomMode || 'browser-default-100-percent',
      screenshotFiles: (result.screenshotFiles || []).map((file) =>
        relative(outputDir, file).replaceAll('\\', '/')),
    };
  }),
};
await writeFile(resolve(outputDir, 'visual-matrix.json'), `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({ outputDir, cases: results.length, browsers: [...requestedBrowsers] }, null, 2));
