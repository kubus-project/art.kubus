/**
 * Guest -> account activation funnel browser QA.
 *
 * Drives the real web bundle as a Meta-ad visitor would arrive
 * (`/map?mode=guest&utm_source=meta&...`), then walks the funnel: anonymous
 * map, open a marker, tap Save, and capture the contextual activation surface
 * and the registration hand-off.
 *
 * Evidence is written to output/playwright/artifacts/activation-funnel/ as
 * screenshots plus a results.json describing what was asserted at each step
 * and each viewport.
 *
 * Usage:
 *   node ./scripts/qa/activation_funnel_smoke.mjs
 *   QA_BROWSERS=chromium,firefox node ./scripts/qa/activation_funnel_smoke.mjs
 */
import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium, firefox } from 'playwright';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '../..');
const artifactDir = path.resolve(
  rootDir,
  process.env.QA_ARTIFACT_DIR || 'output/playwright/artifacts/activation-funnel',
);

const qaPort = Number(process.env.QA_PORT || 8093);
const requestedUrl = (process.env.APP_URL || '').trim();
const appUrl = requestedUrl || `http://127.0.0.1:${qaPort}`;

const browserTypes = { chromium, firefox };
const requestedBrowsers = (process.env.QA_BROWSERS || 'chromium')
  .split(',')
  .map((v) => v.trim())
  .filter(Boolean);

/** Campaign entry exactly as Meta traffic reaches the app. */
const CAMPAIGN_QUERY =
  '?mode=guest&intent=discover&utm_source=meta&utm_medium=paid_social' +
  '&utm_campaign=summer-art&utm_content=creative-b';

const VIEWPORTS = [
  { name: 'mobile-390', width: 390, height: 844, isMobile: true },
  { name: 'mobile-narrow-360', width: 360, height: 740, isMobile: true },
  { name: 'tablet-834', width: 834, height: 1112, isMobile: false },
  { name: 'desktop-1440', width: 1440, height: 900, isMobile: false },
];

await fs.mkdir(artifactDir, { recursive: true });

async function waitForHttp(url, timeoutMs = 60000) {
  const deadline = Date.now() + timeoutMs;
  let lastError = null;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(2000) });
      if (response.ok || response.status === 404) return;
    } catch (error) {
      lastError = error;
    }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`Timed out waiting for ${url}: ${lastError?.message || 'no response'}`);
}

async function startProxyIfNeeded() {
  if (requestedUrl) return null;
  const log = await fs.open(path.join(artifactDir, 'proxy.log'), 'w');
  const child = spawn(process.execPath, [path.join(__dirname, 'dev_spa_proxy.mjs')], {
    cwd: rootDir,
    env: { ...process.env, PORT: String(qaPort) },
    stdio: ['ignore', 'pipe', 'pipe'],
    windowsHide: true,
  });
  child.stdout.on('data', (c) => log.write(c).catch(() => {}));
  child.stderr.on('data', (c) => log.write(c).catch(() => {}));
  child.on('exit', (code) => {
    log.write(`\nproxy exited code=${code}\n`).catch(() => {});
    log.close().catch(() => {});
  });
  await waitForHttp(appUrl);
  return child;
}

/**
 * A single deterministic public artwork.
 *
 * The live proxy answers guest reads with 403 in this environment, so the map
 * has nothing to tap. Seeding one public artwork lets the run exercise the real
 * gate on the real bundle instead of asserting against an empty map.
 */
const QA_ARTWORK_ID = 'qa-artwork-1';
const QA_ARTWORK = {
  id: QA_ARTWORK_ID,
  title: 'QA Mural',
  description: 'A public mural seeded for activation funnel QA.',
  artist: 'QA Artist',
  category: 'street_art',
  latitude: 46.0569,
  longitude: 14.5058,
  isPublic: true,
  isPublished: true,
  likesCount: 3,
  viewsCount: 12,
  isLikedByCurrentUser: false,
  isFavoriteByCurrentUser: false,
  createdAt: '2026-07-01T10:00:00.000Z',
  updatedAt: '2026-07-01T10:00:00.000Z',
};

function stubApi(pathname, method) {
  const json = (body, status = 200) => ({
    status,
    contentType: 'application/json; charset=utf-8',
    body: JSON.stringify(body),
  });

  if (method !== 'GET' && /\/api\/(analytics|diagnostics)\//.test(pathname)) {
    return { status: 204, body: '' };
  }
  if (pathname.endsWith(`/api/artworks/${QA_ARTWORK_ID}`)) {
    return json({ artwork: QA_ARTWORK });
  }
  if (pathname.endsWith('/api/artworks')) {
    return json({ data: [QA_ARTWORK], artworks: [QA_ARTWORK] });
  }
  if (pathname.endsWith('/api/art-markers')) {
    return json({
      data: [
        {
          id: 'qa-marker-1',
          title: QA_ARTWORK.title,
          latitude: QA_ARTWORK.latitude,
          longitude: QA_ARTWORK.longitude,
          type: 'streetArt',
          isPublic: true,
          artworkId: QA_ARTWORK_ID,
        },
      ],
    });
  }
  if (/\/health/.test(pathname)) {
    return json({ status: 'ok', ready: true, writable: true });
  }
  return json({ data: [], success: true });
}

/** Flutter renders to canvas; text lives in the semantics tree. */
async function enableSemantics(page) {
  await page.evaluate(() => {
    const el = document.querySelector('flt-semantics-placeholder')
      || document.querySelector('[aria-label="Enable accessibility"]');
    if (el) el.click();
  }).catch(() => {});
  await page.waitForTimeout(700);
}

async function semanticsText(page) {
  return page.evaluate(() => {
    const host = document.querySelector('flt-semantics-host') || document.body;
    return (host.innerText || '').replace(/\s+/g, ' ').trim();
  });
}

async function shoot(page, name) {
  const file = path.join(artifactDir, `${name}.png`);
  await page.screenshot({ path: file, fullPage: false });
  return path.relative(rootDir, file);
}

/**
 * Clicks the semantics node whose accessible label matches.
 *
 * Flutter's semantics tree nests containers around leaves, and clicking a
 * container hits nothing. So: match on aria-label, keep only nodes with a real
 * box, prefer the smallest (the leaf), and click its centre through the mouse
 * so the hit test lands on the canvas the way a real tap does.
 */
async function clickSemantic(page, pattern) {
  const box = await page.evaluate((source) => {
    const re = new RegExp(source, 'i');
    // Flutter web exposes the accessible name either as aria-label or as the
    // node's own text; buttons on these screens use the latter.
    const nameOf = (n) => (n.getAttribute('aria-label') || n.textContent || '').trim();
    const nodes = Array.from(document.querySelectorAll('flt-semantics'));
    const matches = nodes
      .filter((n) => re.test(nameOf(n)))
      .sort((a, b) => {
        const aButton = a.getAttribute('role') === 'button' ? 0 : 1;
        const bButton = b.getAttribute('role') === 'button' ? 0 : 1;
        if (aButton !== bButton) return aButton - bButton;
        const ra = a.getBoundingClientRect();
        const rb = b.getBoundingClientRect();
        return ra.width * ra.height - rb.width * rb.height;
      })
      .filter((n) => {
        const r = n.getBoundingClientRect();
        return r.width > 4 && r.height > 4;
      });
    const node = matches[0];
    if (node) node.scrollIntoView({ block: 'center' });
    const rect = node ? node.getBoundingClientRect() : null;
    return rect ? { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 } : null;
  }, pattern.source ?? String(pattern));

  if (!box) return false;
  try {
    await page.mouse.click(box.x, box.y);
    await page.waitForTimeout(1100);
    return true;
  } catch {
    return false;
  }
}

const results = { appUrl, startedAt: new Date().toISOString(), runs: [] };
let proxy = null;

try {
  proxy = await startProxyIfNeeded();

  for (const browserName of requestedBrowsers) {
    const browserType = browserTypes[browserName];
    if (!browserType) throw new Error(`Unsupported QA browser: ${browserName}`);
    const browser = await browserType.launch();

    for (const viewport of VIEWPORTS) {
      const run = {
        browser: browserName,
        viewport: viewport.name,
        size: `${viewport.width}x${viewport.height}`,
        steps: [],
        consoleErrors: [],
        screenshots: [],
      };

      const context = await browser.newContext({
        viewport: { width: viewport.width, height: viewport.height },
        isMobile: viewport.isMobile,
        hasTouch: viewport.isMobile,
        deviceScaleFactor: 2,
      });
      const page = await context.newPage();
      page.on('console', (msg) => {
        if (msg.type() === 'error') run.consoleErrors.push(msg.text().slice(0, 300));
      });
      page.on('pageerror', (err) => run.consoleErrors.push(String(err).slice(0, 300)));

      await page.route('**/api/**', async (route) => {
        const request = route.request();
        const { pathname } = new URL(request.url());
        await route.fulfill(stubApi(pathname, request.method()));
      });

      try {
        // 1. Anonymous campaign landing on the public map.
        await page.goto(`${appUrl}/map${CAMPAIGN_QUERY}`, {
          waitUntil: 'domcontentloaded',
          timeout: 60000,
        });
        await page.waitForTimeout(9000);
        await enableSemantics(page);
        run.screenshots.push(await shoot(page, `${browserName}-${viewport.name}-01-anonymous-map`));

        const landedText = await semanticsText(page);
        run.steps.push({
          step: 'anonymous_map_loaded',
          // The whole premise: no auth wall on arrival.
          noAuthWall: !/sign in to art\.kubus|create your account/i.test(landedText),
          url: page.url(),
        });

        // 2. Campaign attribution persisted for the session.
        const attribution = await page.evaluate(() => {
          const out = {};
          for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key && (key.includes('kubus_entry_utm') || key.includes('kubus_guest_mode')
              || key.includes('kubus_entry_intent'))) {
              out[key] = localStorage.getItem(key);
            }
          }
          return out;
        });
        run.steps.push({ step: 'campaign_attribution_persisted', attribution });

        // 3. Open a public artwork as a guest.
        await page.goto(`${appUrl}/a/${QA_ARTWORK_ID}`, {
          waitUntil: 'domcontentloaded',
          timeout: 60000,
        });
        await page.waitForTimeout(7000);
        await enableSemantics(page);
        const artworkText = await semanticsText(page);
        run.screenshots.push(
          await shoot(page, `${browserName}-${viewport.name}-02-artwork-open`),
        );
        run.steps.push({
          step: 'guest_opens_public_artwork',
          artworkVisible: /qa mural/i.test(artworkText),
          saveAffordanceVisible: /save|shrani/i.test(artworkText),
        });

        // 4. Attempt Save -> the contextual activation surface.
        const tappedSave = await clickSemantic(page, /^(save|shrani)$/)
            || await clickSemantic(page, /\b(save|shrani)\b/);
        await page.waitForTimeout(1400);
        const gateText = await semanticsText(page);
        const gateShown =
          /save this artwork to your collection|shrani to umetnino v svojo zbirko/i.test(gateText);
        run.screenshots.push(
          await shoot(page, `${browserName}-${viewport.name}-03-activation-gate`),
        );
        run.steps.push({
          step: 'contextual_activation_surface',
          saveTapped: tappedSave,
          gateShown,
          googlePrimary: /continue with google|nadaljuj z google/i.test(gateText),
          emailOffered: /continue with email|nadaljuj z e-po/i.test(gateText),
          notNowOffered: /not now|ne zdaj/i.test(gateText),
          // The anti-pattern this work removed.
          usesGenericSignInCopy: /sign-in required/i.test(gateText),
        });

        // 5. Dismissing returns to the same artwork with browsing intact.
        const dismissed = await clickSemantic(page, /^(not now|ne zdaj)$/);
        await page.waitForTimeout(1200);
        const afterDismiss = await semanticsText(page);
        run.screenshots.push(
          await shoot(page, `${browserName}-${viewport.name}-04-dismissed-back-on-artwork`),
        );
        run.steps.push({
          step: 'dismiss_preserves_context',
          dismissed,
          stillOnArtwork: /qa mural/i.test(afterDismiss),
          gateGone: !/save this artwork to your collection/i.test(afterDismiss),
        });

        // 4. Registration surface, reached from the gate.
        await page.goto(`${appUrl}/register`, {
          waitUntil: 'domcontentloaded',
          timeout: 60000,
        });
        await page.waitForTimeout(6000);
        await enableSemantics(page);
        run.screenshots.push(
          await shoot(page, `${browserName}-${viewport.name}-05-register-methods`),
        );
        const registerText = await semanticsText(page);
        run.steps.push({
          step: 'registration_methods',
          googleOffered: /google/i.test(registerText),
          emailOffered: /email|e-po/i.test(registerText),
        });

        // 5. Verification-pending surface.
        await page.goto(`${appUrl}/verify-email?email=qa%40example.com`, {
          waitUntil: 'domcontentloaded',
          timeout: 60000,
        });
        await page.waitForTimeout(5000);
        await enableSemantics(page);
        run.screenshots.push(
          await shoot(page, `${browserName}-${viewport.name}-06-verification-pending`),
        );

        // 6. Slovenian rendering of the same landing.
        await page.goto(`${appUrl}/map${CAMPAIGN_QUERY}&lang=sl`, {
          waitUntil: 'domcontentloaded',
          timeout: 60000,
        });
        await page.waitForTimeout(8000);
        await enableSemantics(page);
        run.screenshots.push(
          await shoot(page, `${browserName}-${viewport.name}-07-map-slovenian`),
        );

        run.ok = true;
      } catch (error) {
        run.ok = false;
        run.error = String(error).slice(0, 500);
        try {
          run.screenshots.push(await shoot(page, `${browserName}-${viewport.name}-error`));
        } catch { /* ignore */ }
      } finally {
        await context.close();
      }

      results.runs.push(run);
      const status = run.ok ? 'ok' : 'FAILED';
      // eslint-disable-next-line no-console
      console.log(`[${browserName}] ${viewport.name}: ${status}`);
    }

    await browser.close();
  }
} finally {
  results.finishedAt = new Date().toISOString();
  await fs.writeFile(
    path.join(artifactDir, 'results.json'),
    `${JSON.stringify(results, null, 2)}\n`,
    'utf8',
  );
  if (proxy) proxy.kill();
}

const failed = results.runs.filter((r) => !r.ok);
// eslint-disable-next-line no-console
console.log(`\n${results.runs.length - failed.length}/${results.runs.length} runs ok`);
// eslint-disable-next-line no-console
console.log(`artifacts: ${path.relative(rootDir, artifactDir)}`);
if (failed.length) process.exitCode = 1;
