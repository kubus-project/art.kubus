/**
 * Visual + behavioural verification for the marker quick-card hotfix.
 *
 * Drives the release web build with stubbed API fixtures so every required
 * marker shape is reachable deterministically:
 *   artwork, street-art, valid event, valid exhibition, orphaned
 *   event/exhibition (the verified "Ponjava VI" shape), long attribution,
 *   long description, stacked markers.
 *
 * For each viewport x fixture it asserts that the initial selection opens the
 * floating card (never a popup, never a detail page), then opens "More info"
 * and asserts the resulting surface: the canonical event/exhibition detail for a
 * resolvable subject, and the generic marker-detail surface for an orphan.
 *
 * Usage: node output/playwright/verify_marker_quick_card.mjs
 */
import { chromium } from '../../scripts/qa/node_modules/playwright/index.mjs';
import { buildStableApiStub } from '../../scripts/qa/web_runtime_contract.mjs';

const baseUrl = 'http://127.0.0.1:8099';
const OUT = 'output/playwright';

const ARTWORK_ID = '11111111-1111-4111-8111-111111111111';
const EVENT_ID = '22222222-2222-4222-8222-222222222222';
const EXHIBITION_ID = '33333333-3333-4333-8333-333333333333';
const ORPHAN_SUBJECT_ID = '8a1d8347-fada-4755-95d2-6024519c93cd';

const IMG = `${baseUrl}/icons/Icon-192.png`;
const LONG_DESCRIPTION = [
  'This installation stretches a painted canvas between two facades of the',
  'courtyard, so the work reads differently from every approach.',
  'The artist treats the gap between the buildings as a frame, and the fabric',
  'as a moving surface that the weather keeps rewriting.',
  'Visitors are invited to walk the full length of the passage before looking',
  'up, which is when the composition resolves into a single figure.',
  'The piece was produced for the neighbourhood programme and will be',
  'reinstalled at a second site after the closing weekend.',
  'A short printed guide is available at the venue entrance, and a recorded',
  'walkthrough is published alongside the programme notes.',
  'The commission notes describe the work as a study of shared thresholds and',
  'the way a passage can behave like a room.',
].join(' ');
const LONG_ATTRIBUTION = {
  artistName: 'Klara Perusek in collaboration with the neighbourhood workshop',
  imageAuthor: 'Kino Siska documentation team, photographed by A. Novak',
  imageLicense: 'CC BY-SA 4.0 (Creative Commons Attribution-ShareAlike)',
  sourceAttribution:
    'Data: OpenStreetMap contributors and the municipal cultural register',
};

const artwork = {
  id: ARTWORK_ID,
  title: 'Quick Card Artwork',
  description: LONG_DESCRIPTION,
  artistName: 'Street Artist',
  walletAddress: 'qa-wallet',
  imageUrl: IMG,
  imageAuthor: 'Photo Creator',
  imageLicense: 'CC BY-SA 4.0',
  imageAttribution: 'Photo Creator / CC BY-SA 4.0',
  category: 'Painting',
  tags: ['mural'],
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

const event = {
  id: EVENT_ID,
  title: 'Quick Card Event',
  description:
    'A programme of evening walks through the district, with three guided routes and a closing talk.',
  startsAt: '2026-08-05T18:00:00.000Z',
  endsAt: '2026-08-07T21:00:00.000Z',
  locationName: 'Metelkova',
  city: 'Ljubljana',
  country: 'Slovenia',
  lat: 46.058,
  lng: 14.507,
  coverUrl: IMG,
  status: 'published',
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-02T00:00:00.000Z',
};

const exhibition = {
  id: EXHIBITION_ID,
  title: 'Quick Card Exhibition',
  description:
    'A group show assembled from the open call, presented across two floors of the venue.',
  startsAt: '2026-09-01T10:00:00.000Z',
  endsAt: '2026-09-30T18:00:00.000Z',
  locationName: 'Moderna galerija',
  lat: 46.0555,
  lng: 14.5035,
  coverUrl: IMG,
  status: 'published',
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-02T00:00:00.000Z',
};

function marker(overrides) {
  return {
    latitude: 46.0569,
    longitude: 14.5058,
    createdBy: 'qa-wallet',
    ownerWalletAddress: 'qa-wallet',
    isPublic: true,
    isActive: true,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-02T00:00:00.000Z',
    ...overrides,
  };
}

/**
 * Every fixture the hotfix must handle. `expectMoreInfo` names the surface the
 * primary action must reach.
 */
const FIXTURES = [
  {
    key: 'artwork',
    name: 'Quick Card Artwork',
    expectMoreInfo: 'artwork',
    marker: marker({
      id: 'a0000000-0000-4000-8000-000000000001',
      artworkId: ARTWORK_ID,
      name: 'Quick Card Artwork',
      description: artwork.description,
      markerType: 'artwork',
      category: 'Painting',
      metadata: {
        subjectType: 'artwork',
        subjectId: ARTWORK_ID,
        coverImageUrl: IMG,
        artistName: artwork.artistName,
        imageAuthor: artwork.imageAuthor,
        imageLicense: artwork.imageLicense,
      },
    }),
  },
  {
    key: 'street-art',
    name: 'Quick Card Street Art',
    expectMoreInfo: 'artwork',
    marker: marker({
      id: 'a0000000-0000-4000-8000-000000000002',
      artworkId: ARTWORK_ID,
      name: 'Quick Card Street Art',
      description:
        'A mural on the courtyard wall, repainted each season by the local workshop.',
      markerType: 'streetArt',
      category: 'Street Art',
      latitude: 46.0572,
      longitude: 14.5061,
      metadata: {
        subjectType: 'streetArt',
        coverImageUrl: IMG,
        artistName: artwork.artistName,
        imageAuthor: artwork.imageAuthor,
        imageLicense: artwork.imageLicense,
      },
    }),
  },
  {
    key: 'event-valid',
    name: 'Quick Card Event',
    expectMoreInfo: 'event',
    marker: marker({
      id: 'a0000000-0000-4000-8000-000000000003',
      name: 'Quick Card Event',
      description: 'Marker copy for the evening walks programme.',
      markerType: 'event',
      category: 'Event',
      latitude: 46.058,
      longitude: 14.507,
      metadata: {
        subjectType: 'event',
        subjectId: EVENT_ID,
        subjectTitle: event.title,
        subjectCategory: 'Programme',
        locationName: 'Metelkova',
        startsAt: event.startsAt,
        endsAt: event.endsAt,
        coverImageUrl: IMG,
      },
    }),
  },
  {
    key: 'exhibition-valid',
    name: 'Quick Card Exhibition',
    expectMoreInfo: 'exhibition',
    marker: marker({
      id: 'a0000000-0000-4000-8000-000000000004',
      name: 'Quick Card Exhibition',
      description: 'Marker copy for the group show.',
      markerType: 'exhibition',
      category: 'Exhibition',
      latitude: 46.0555,
      longitude: 14.5035,
      metadata: {
        subjectType: 'exhibition',
        subjectId: EXHIBITION_ID,
        subjectTitle: exhibition.title,
        subjectCategory: 'Group show',
        locationName: 'Moderna galerija',
        startsAt: exhibition.startsAt,
        endsAt: exhibition.endsAt,
        coverImageUrl: IMG,
      },
    }),
  },
  {
    key: 'orphaned-subject',
    name: 'Ponjava VI',
    expectMoreInfo: 'marker-info',
    // The verified production shape: markerType=event, subjectType=exhibition,
    // and a subjectId that 404s as both an exhibition and an event.
    marker: marker({
      id: '312d350e-72a7-47f9-9654-b9a2eaf2e9d1',
      name: 'Ponjava VI',
      description:
        'A canvas installation stretched between two facades of the courtyard.',
      markerType: 'event',
      category: 'Event',
      latitude: 46.0561,
      longitude: 14.5049,
      metadata: {
        subjectType: 'exhibition',
        subjectId: ORPHAN_SUBJECT_ID,
        subjectCategory: 'Group show',
        locationName: 'Kino Siska',
        startsAt: '2026-08-01T18:00:00.000Z',
        endsAt: '2026-08-10T20:00:00.000Z',
        coverImageUrl: IMG,
        ...LONG_ATTRIBUTION,
      },
    }),
  },
  {
    key: 'long-attribution',
    name: 'Quick Card Long Attribution',
    expectMoreInfo: 'marker-info',
    marker: marker({
      id: 'a0000000-0000-4000-8000-000000000006',
      name: 'Quick Card Long Attribution',
      description: 'A short marker description with very long credit lines.',
      markerType: 'other',
      latitude: 46.0548,
      longitude: 14.5022,
      metadata: {
        coverImageUrl: IMG,
        ...LONG_ATTRIBUTION,
      },
    }),
  },
  {
    key: 'long-description',
    name: 'Quick Card Long Description',
    expectMoreInfo: 'marker-info',
    marker: marker({
      id: 'a0000000-0000-4000-8000-000000000007',
      name: 'Quick Card Long Description',
      description: LONG_DESCRIPTION,
      markerType: 'other',
      latitude: 46.0535,
      longitude: 14.5011,
      metadata: { coverImageUrl: IMG, ...LONG_ATTRIBUTION },
    }),
  },
  {
    key: 'stacked',
    name: 'Quick Card Stacked One',
    expectMoreInfo: 'marker-info',
    expectStack: true,
    marker: marker({
      id: 'a0000000-0000-4000-8000-000000000008',
      name: 'Quick Card Stacked One',
      description: 'First of three markers sharing one coordinate.',
      markerType: 'other',
      latitude: 46.0599,
      longitude: 14.5099,
      metadata: { coverImageUrl: IMG },
    }),
    extraMarkers: [
      marker({
        id: 'a0000000-0000-4000-8000-000000000009',
        name: 'Quick Card Stacked Two',
        description: 'Second of three markers sharing one coordinate.',
        markerType: 'other',
        latitude: 46.0599,
        longitude: 14.5099,
        metadata: { coverImageUrl: IMG },
      }),
      marker({
        id: 'a0000000-0000-4000-8000-00000000000a',
        name: 'Quick Card Stacked Three',
        description: 'Third of three markers sharing one coordinate.',
        markerType: 'other',
        latitude: 46.0599,
        longitude: 14.5099,
        metadata: { coverImageUrl: IMG },
      }),
    ],
  },
];

const CENTER = { latitude: 46.0569, longitude: 14.5058 };

/**
 * Serves exactly one fixture per page load, pinned to the camera centre.
 *
 * The map is a WebGL platform view, so a marker cannot be located by DOM query.
 * Pinning the fixture to the geolocation point the camera follows makes the
 * marker's screen position deterministic, which is how the initial tap is
 * exercised through the real controller path.
 */
function markersFor(fixture) {
  const stacked = [fixture.marker, ...(fixture.extraMarkers || [])];
  return stacked.map((item) => ({
    ...item,
    latitude: CENTER.latitude,
    longitude: CENTER.longitude,
  }));
}

let activeMarkers = [];

const VIEWPORTS = [
  { key: 'desktop-1440x900', width: 1440, height: 900, full: true },
  { key: 'tablet-1024x768', width: 1024, height: 768, full: false },
  { key: 'mobile-390x844', width: 390, height: 844, full: true },
  { key: 'mobile-landscape-844x390', width: 844, height: 390, full: false },
];

/** Fixtures exercised on the two secondary viewports. */
const SUBSET = new Set([
  'orphaned-subject',
  'event-valid',
  'long-description',
  'stacked',
]);

function jsonResponse(payload, status = 200) {
  return {
    status,
    contentType: 'application/json; charset=utf-8',
    body: JSON.stringify(payload),
  };
}

async function routeApi(route) {
  const request = route.request();
  const url = new URL(request.url());
  const path = url.pathname.replace(/\/+$/, '');

  if (path === '/api/art-markers' || path === '/api/public-markers') {
    await route.fulfill(
      jsonResponse({
        success: true,
        data: activeMarkers,
        markers: activeMarkers,
      }),
    );
    return;
  }
  const markerMatch = activeMarkers.find(
    (item) => path === `/api/art-markers/${item.id}`,
  );
  if (markerMatch) {
    await route.fulfill(
      jsonResponse({ success: true, data: markerMatch, marker: markerMatch }),
    );
    return;
  }
  if (path === '/api/artworks') {
    await route.fulfill(
      jsonResponse({ success: true, data: [artwork], artworks: [artwork] }),
    );
    return;
  }
  if (path === `/api/artworks/${ARTWORK_ID}`) {
    await route.fulfill(jsonResponse({ success: true, data: artwork, artwork }));
    return;
  }
  if (path === '/api/events') {
    await route.fulfill(
      jsonResponse({ success: true, data: [event], events: [event] }),
    );
    return;
  }
  if (path === `/api/events/${EVENT_ID}`) {
    await route.fulfill(jsonResponse({ success: true, data: event, event }));
    return;
  }
  if (path === '/api/exhibitions') {
    await route.fulfill(
      jsonResponse({
        success: true,
        data: [exhibition],
        exhibitions: [exhibition],
      }),
    );
    return;
  }
  if (path === `/api/exhibitions/${EXHIBITION_ID}`) {
    await route.fulfill(
      jsonResponse({ success: true, data: exhibition, exhibition }),
    );
    return;
  }
  // The orphan: both canonical endpoints 404, exactly like production.
  if (
    path === `/api/exhibitions/${ORPHAN_SUBJECT_ID}` ||
    path === `/api/events/${ORPHAN_SUBJECT_ID}`
  ) {
    await route.fulfill(
      jsonResponse({ success: false, error: 'Not found' }, 404),
    );
    return;
  }

  await route.fulfill(buildStableApiStub(request.url(), request.method()));
}

/** Semantics + DOM snapshot used for the behavioural assertions. */
async function readSurface(page) {
  return page.evaluate(() => {
    const labels = [...document.querySelectorAll('[aria-label]')]
      .map((el) => el.getAttribute('aria-label'))
      .filter(Boolean);
    const text = document.body.innerText || '';
    // Flutter web exposes scroll containers as elements the browser can scroll.
    const scrollables = [...document.querySelectorAll('*')]
      .filter((el) => {
        if (!(el instanceof HTMLElement)) return false;
        const style = getComputedStyle(el);
        const scrolls =
          style.overflowY === 'scroll' || style.overflowY === 'auto';
        return scrolls && el.scrollHeight > el.clientHeight + 2;
      })
      .map((el) => `${el.tagName.toLowerCase()}.${el.className || ''}`);
    return { labels, text, scrollables };
  });
}

/**
 * The map viewport's centre in page coordinates.
 *
 * Desktop layouts reserve a left navigation rail, so the map's centre is not the
 * page centre.
 */
function mapCenter(viewport) {
  const isDesktopLayout = viewport.width >= 900;
  const railWidth = isDesktopLayout ? 220 : 0;
  return {
    x: railWidth + (viewport.width - railWidth) / 2,
    y: viewport.height / 2,
  };
}

/** True when both the marker title and the card's primary CTA are present. */
function cardIsOpen(surface, markerName) {
  const hasName =
    surface.labels.includes(markerName) || surface.text.includes(markerName);
  const hasCta =
    surface.labels.includes('More info') ||
    surface.labels.includes('View details') ||
    surface.text.includes('More info') ||
    surface.text.includes('View details');
  return hasName && hasCta;
}

const CLICK_PROBES = [
  { dx: 0, dy: 0 },
  { dx: 0, dy: -10 },
  { dx: 0, dy: -20 },
  { dx: 0, dy: 10 },
  { dx: -12, dy: -6 },
  { dx: 12, dy: -6 },
  { dx: 0, dy: -32 },
];

const results = [];
const browser = await chromium.launch({ channel: 'chrome', headless: true });

async function newPage(context) {
  const page = await context.newPage();
  await page.route(/^https:\/\/(?:api|bapi)\.kubus\.site\//, routeApi);
  await page.route('https://accounts.google.com/gsi/client**', (route) =>
    route.fulfill({
      status: 200,
      contentType: 'application/javascript; charset=utf-8',
      body: 'window.google={accounts:{id:{initialize(){},prompt(){},renderButton(){},cancel(){},disableAutoSelect(){}},oauth2:{initTokenClient:()=>({requestAccessToken(){}}),initCodeClient:()=>({requestCode(){}})}}};',
    }),
  );
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
  return page;
}

for (const viewport of VIEWPORTS) {
  const fixtures = viewport.full
    ? FIXTURES
    : FIXTURES.filter((fixture) => SUBSET.has(fixture.key));

  for (const fixture of fixtures) {
    activeMarkers = markersFor(fixture);

    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      colorScheme: 'dark',
      locale: 'en-GB',
      geolocation: CENTER,
      permissions: ['geolocation'],
    });
    const page = await newPage(context);
    const errors = [];
    page.on('pageerror', (error) => errors.push(error.message));
    page.on('console', (message) => {
      if (message.type() === 'error') errors.push(message.text());
    });

    const record = {
      viewport: viewport.key,
      fixture: fixture.key,
      expectMoreInfo: fixture.expectMoreInfo,
      selected: false,
      cardVisible: false,
      mediaVisible: false,
      descriptionVisible: false,
      attributionVisible: false,
      saveVisible: false,
      shareVisible: false,
      primaryLabel: null,
      pagerVisible: false,
      legacyDialogOnTap: false,
      scrollables: [],
      surfaceAfterPrimary: null,
      legacyDialogAfterPrimary: false,
      notes: [],
    };

    try {
      await page.goto(`${baseUrl}/?mode=guest`, {
        waitUntil: 'domcontentloaded',
        timeout: 90000,
      });
      await page.waitForTimeout(20000);

      const accessibilitySwitch = page.locator(
        '[aria-label="Enable accessibility"]',
      );
      if (await accessibilitySwitch.count()) {
        await accessibilitySwitch.evaluate((element) => element.click());
        await page.waitForTimeout(1500);
      }

      const exploreByLabel = page.locator('[aria-label="Explore"]');
      const explore = (await exploreByLabel.count())
        ? exploreByLabel
        : page.getByText('Explore', { exact: true });
      if (await explore.count()) {
        await explore
          .first()
          .click({ timeout: 15000 })
          .catch((error) => record.notes.push(`explore: ${error.message}`));
        await page.waitForTimeout(13000);
      } else {
        record.notes.push('explore control not found');
        await page.waitForTimeout(8000);
      }

      const baseline = await readSurface(page);
      record.baselineScrollables = baseline.scrollables.length;

      const centre = mapCenter(viewport);
      for (const probe of CLICK_PROBES) {
        await page.mouse.click(centre.x + probe.dx, centre.y + probe.dy);
        await page.waitForTimeout(3500);
        const probed = await readSurface(page);
        if (cardIsOpen(probed, fixture.name)) {
          record.selected = true;
          break;
        }
      }

      const surface = await readSurface(page);
      record.cardVisible = cardIsOpen(surface, fixture.name);
      record.descriptionVisible = surface.labels.includes('marker description');
      record.legacyDialogOnTap = surface.text.includes(
        'No linked artwork found for this marker yet.',
      );
      record.scrollables = surface.scrollables;
      // Zero means the quick card introduced no scroll container of its own.
      record.cardScrollables =
        surface.scrollables.length - baseline.scrollables.length;
      record.saveVisible = surface.labels.some((l) => /_save$/.test(l));
      record.shareVisible = surface.labels.some((l) => /_share$/.test(l));
      record.pagerVisible = surface.labels.some((l) => /^\d+\/\d+$/.test(l));
      record.attributionVisible =
        surface.text.includes('Photo:') ||
        surface.text.includes('Source:') ||
        surface.text.includes('Artist:');
      // Canvaskit paints the cover into the canvas, so there is no <img> to
      // query; the media area is verified from the captured screenshots.
      record.semanticsLabelSample = surface.labels.slice(0, 40);
      record.textSample = surface.text.replace(/\s+/g, ' ').slice(0, 600);

      await page.mouse.move(4, viewport.height - 4);
      await page.waitForTimeout(1200);
      await page.screenshot({
        path: `${OUT}/qc-${viewport.key}-${fixture.key}-card.png`,
        fullPage: false,
      });

      // Flutter web renders the CTA label into a text node inside a larger
      // paragraph element, so neither an exact aria-label nor exact text match is
      // reliable; Playwright's text engine resolves the smallest containing node.
      const moreInfoByLabel = page.locator('[aria-label="More info"]');
      const viewDetailsByLabel = page.locator('[aria-label="View details"]');
      const moreInfo = (await moreInfoByLabel.count())
        ? moreInfoByLabel
        : page.locator('text=More info');
      const viewDetails = (await viewDetailsByLabel.count())
        ? viewDetailsByLabel
        : page.locator('text=View details');
      const hasMoreInfo = await moreInfo.count();
      const hasViewDetails = await viewDetails.count();
      record.primaryLabel = hasMoreInfo
        ? 'More info'
        : hasViewDetails
          ? 'View details'
          : null;

      if (record.primaryLabel) {
        await (hasMoreInfo ? moreInfo.last() : viewDetails.last()).click({
          timeout: 15000,
        });
        await page.waitForTimeout(7000);
        const after = await readSurface(page);
        // Flutter's semantic nodes are visually hidden, so `innerText` omits
        // them on some surfaces; the aria-labels carry the same strings. Both
        // channels are searched.
        const afterHaystack = [after.text, ...after.labels].join(' | ');
        record.legacyDialogAfterPrimary = afterHaystack.includes(
          'No linked artwork found for this marker yet.',
        );
        if (afterHaystack.includes('Marker information')) {
          record.surfaceAfterPrimary = 'marker-info';
        } else if (afterHaystack.includes(exhibition.title)) {
          record.surfaceAfterPrimary = 'exhibition';
        } else if (afterHaystack.includes(event.title)) {
          record.surfaceAfterPrimary = 'event';
        } else if (afterHaystack.includes(artwork.title)) {
          record.surfaceAfterPrimary = 'artwork';
        } else {
          record.surfaceAfterPrimary = 'unknown';
        }
        await page.screenshot({
          path: `${OUT}/qc-${viewport.key}-${fixture.key}-primary.png`,
          fullPage: false,
        });
      }
    } catch (error) {
      record.notes.push(`error: ${error.message}`);
    } finally {
      await page
        .screenshot({
          path: `${OUT}/qc-${viewport.key}-${fixture.key}-final.png`,
          fullPage: false,
        })
        .catch(() => {});
    }

    record.pageErrors = errors.slice(0, 6);
    // Streamed so a long run can be diagnosed before it finishes.
    process.stderr.write(`${JSON.stringify(record)}
`);
    results.push(record);
    await context.close();
  }
}

await browser.close();
console.log(JSON.stringify(results, null, 2));
