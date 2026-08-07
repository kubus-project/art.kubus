import { chromium } from '../../scripts/qa/node_modules/playwright/index.mjs';
import { buildStableApiStub } from '../../scripts/qa/web_runtime_contract.mjs';

const baseUrl = 'http://127.0.0.1:8090';
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const artworkId = '11111111-1111-4111-8111-111111111111';
const markerId = '22222222-2222-4222-8222-222222222222';
const artwork = {
  id: artworkId,
  title: 'Unified Street Art',
  description:
    'A public mural used to verify the unified map artwork experience.',
  artistName: 'Street Artist',
  walletAddress: 'qa-wallet',
  imageUrl: `${baseUrl}/icons/Icon-192.png`,
  imageAuthor: 'Photo Creator',
  imageLicense: 'CC BY-SA 4.0',
  imageAttribution: 'Photo Creator / CC BY-SA 4.0',
  imageSourceUrl: 'https://example.test/source',
  category: 'Street Art',
  tags: ['street art', 'mural'],
  latitude: 46.0569,
  longitude: 14.5058,
  likesCount: 7,
  commentsCount: 3,
  viewsCount: 12,
  isLikedByCurrentUser: false,
  isFavoriteByCurrentUser: false,
  rewards: 10,
  isPublic: true,
  isActive: true,
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-02T00:00:00.000Z',
};
const marker = {
  id: markerId,
  artworkId,
  name: 'Unified Street Art',
  description: artwork.description,
  latitude: 46.0569,
  longitude: 14.5058,
  markerType: 'street_art',
  category: 'Street Art',
  createdBy: 'qa-wallet',
  ownerWalletAddress: 'qa-wallet',
  isPublic: true,
  isActive: true,
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-02T00:00:00.000Z',
  metadata: {
    subjectType: 'streetArt',
    linkedArtworkId: artworkId,
    linkedArtworkTitle: artwork.title,
    coverImageUrl: artwork.imageUrl,
    artistName: artwork.artistName,
    imageAuthor: artwork.imageAuthor,
    imageLicense: artwork.imageLicense,
    coverImageAttribution: artwork.imageAttribution,
  },
};

function jsonResponse(payload) {
  return {
    status: 200,
    contentType: 'application/json; charset=utf-8',
    body: JSON.stringify(payload),
  };
}

async function inspect(name, viewport) {
  const context = await browser.newContext({
    viewport,
    colorScheme: 'dark',
    locale: 'en-GB',
    geolocation: { latitude: 46.0569, longitude: 14.5058 },
    permissions: ['geolocation'],
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  await page.route(/^https:\/\/(?:api|bapi)\.kubus\.site\//, async (route) => {
    const url = new URL(route.request().url());
    const path = url.pathname.replace(/\/+$/, '');
    if (path === '/api/art-markers') {
      await route.fulfill(jsonResponse({ data: [marker], markers: [marker] }));
      return;
    }
    if (path === `/api/art-markers/${markerId}`) {
      await route.fulfill(jsonResponse({ data: marker, marker }));
      return;
    }
    if (path === '/api/artworks') {
      await route.fulfill(jsonResponse({ data: [artwork], artworks: [artwork] }));
      return;
    }
    if (path === `/api/artworks/${artworkId}`) {
      await route.fulfill(jsonResponse({ data: artwork, artwork }));
      return;
    }
    await route.fulfill(
      buildStableApiStub(route.request().url(), route.request().method()),
    );
  });
  await page.route('https://accounts.google.com/gsi/client**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/javascript; charset=utf-8',
      body: `
        window.google = {
          accounts: {
            id: {
              initialize: () => {},
              prompt: () => {},
              renderButton: () => {},
              cancel: () => {},
              disableAutoSelect: () => {}
            },
            oauth2: {
              initTokenClient: () => ({ requestAccessToken: () => {} }),
              initCodeClient: () => ({ requestCode: () => {} })
            }
          }
        };
      `,
    });
  });
  await page.addInitScript(() => {
    const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
    set('has_completed_onboarding', 'true');
    set('has_seen_welcome', 'true');
    set('is_first_launch', 'false');
    set('skipOnboardingForReturningUsers', 'true');
    set('map_onboarding_mobile_seen_v2', 'true');
    set('map_onboarding_desktop_seen_v2', 'true');
    set('selected_language', JSON.stringify('en'));
  });
  const response = await page.goto(`${baseUrl}/`, {
    waitUntil: 'domcontentloaded',
    timeout: 60000,
  });
  await page.waitForTimeout(20000);
  const accessibilitySwitch = page.locator(
    '[aria-label="Enable accessibility"]',
  );
  if (await accessibilitySwitch.count()) {
    await accessibilitySwitch.evaluate((element) => element.click());
    await page.waitForTimeout(1000);
  }
  const exploreLink = page.getByText('Explore', { exact: true });
  if (await exploreLink.count()) {
    await exploreLink.first().click();
    await page.waitForTimeout(15000);
  }
  await page.screenshot({
    path: 'output/playwright/desktop-map-surface.png',
    fullPage: true,
  });
  const nearbyButton = page.getByText('Nearby artworks', { exact: true });
  if (await nearbyButton.count()) {
    await nearbyButton.first().click();
    await page.waitForTimeout(2500);
  }
  const fixtureResult = page.getByText('Unified Street Art', { exact: false });
  try {
    await fixtureResult.last().waitFor({ state: 'visible', timeout: 10000 });
  } catch {
    // The count below is included in the evidence output.
  }
  const fixtureResultCount = await fixtureResult.count();
  if (fixtureResultCount) {
    await fixtureResult.last().click();
    await page.waitForTimeout(5000);
  }
  await page.screenshot({
    path: `output/playwright/${name}.png`,
    fullPage: true,
  });
  const detailsButton = page.getByText('View details', { exact: false });
  try {
    await detailsButton.last().waitFor({ state: 'visible', timeout: 5000 });
  } catch {
    // The count below is included in the evidence output.
  }
  const detailsButtonCount = await detailsButton.count();
  if (detailsButtonCount) {
    await detailsButton.last().click();
    await page.waitForTimeout(6000);
    await page.screenshot({
      path: 'output/playwright/desktop-marker-details.png',
      fullPage: true,
    });
  }
  const state = await page.evaluate(() => ({
    href: location.href,
    text: (document.body.innerText || '').slice(0, 5000),
    labels: [...document.querySelectorAll('[aria-label]')]
      .map((element) => element.getAttribute('aria-label'))
      .filter(Boolean)
      .slice(0, 200),
  }));
  console.log(JSON.stringify({
    name,
    responseStatus: response?.status(),
    fixtureResultCount,
    detailsButtonCount,
    ...state,
    errors,
  }, null, 2));
  if (name === 'desktop-map-ready') {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(5000);
    await page.mouse.click(195, 382);
    await page.waitForTimeout(4000);
    await page.screenshot({
      path: 'output/playwright/mobile-marker-overlay.png',
      fullPage: true,
    });
    const mobileState = await page.evaluate(() => ({
      href: location.href,
      text: (document.body.innerText || '').slice(0, 5000),
      labels: [...document.querySelectorAll('[aria-label]')]
        .map((element) => element.getAttribute('aria-label'))
        .filter(Boolean)
        .slice(0, 200),
    }));
    console.log(JSON.stringify({
      name: 'mobile-map-ready',
      ...mobileState,
      errors,
    }, null, 2));
  }
  await context.close();
}

await inspect('desktop-map-ready', { width: 1440, height: 1000 });
await browser.close();
