// Wave 5A-E guest-first entry browser QA.
//
// Serves a prebuilt Flutter web bundle and drives a *fresh-storage* visitor
// through the entry contract in real Chromium and Firefox:
//
//   fresh /, /main, /map        -> public discovery, nothing in front of it
//   public entity (artwork)     -> exact entity; Back / Forward / refresh stay public
//   protected action (Save)     -> contextual activation sheet; dismiss; retry
//   explicit /register, /sign-in-> still open their own flow
//
// Flutter draws to a canvas, so the check is made against the accessibility
// semantics tree (enabled through the framework's own placeholder button) plus
// screenshots for the visual read. Network is contained: GETs to the public
// read API pass through; analytics and every write are answered locally, so no
// telemetry reaches production and no account is created.
//
//   QA_WEB_ROOT=build/web QA_LABEL=after node scripts/qa/guest_first_entry_browser_qa.mjs
//
// Env: QA_BROWSERS=chromium,firefox  QA_SCENARIOS=fresh,entity,action,explicit
//      QA_ARTWORK_ID=<uuid>  QA_VIEWPORTS=390,320,1440  QA_SCHEMES=light,dark
//      QA_LOCALES=en-US,sl-SI
// Output: output/playwright/guest-first-entry/<label>/ + manifest.json
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium, firefox } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const label = (process.env.QA_LABEL || 'after').trim();
const outDir = path.resolve(rootDir, 'output/playwright/guest-first-entry', label);
const port = Number(process.env.QA_PORT || 8099);
const appUrl = `http://127.0.0.1:${port}`;
const apiOrigin = process.env.QA_API_ORIGIN || 'https://api.kubus.site';
const artworkId = process.env.QA_ARTWORK_ID || '9c077e3a-dedd-53d4-a0f2-bf3b5bc4817b';

const list = (name, fallback) =>
  (process.env[name] || fallback).split(',').map((s) => s.trim()).filter(Boolean);
const browsers = list('QA_BROWSERS', 'chromium,firefox');
const scenarios = list('QA_SCENARIOS', 'fresh,entity,action,explicit');
const widths = list('QA_VIEWPORTS', '390,320,1440').map(Number);
const schemes = list('QA_SCHEMES', 'light,dark');
const locales = list('QA_LOCALES', 'en-US,sl-SI');

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
};

// Anything that would mean something stood in front of discovery. Matched
// case-insensitively against the semantics tree text of a fresh first frame.
const FORBIDDEN_FIRST_FRAME = [
  /alpha/i,
  /welcome to/i,
  /choose one path/i,
  /get started/i,
  /choose your role/i,
  /izberi svojo vlogo/i,
  /enable notifications/i,
  /allow location/i,
  /connect (your )?wallet/i,
  /create (your )?(an )?account/i,
  /sign in to continue/i,
];

function startServer() {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, appUrl);
    let rel = decodeURIComponent(url.pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(webRoot, rel);
    if (!file.startsWith(webRoot)) {
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

const isAnalytics = (u) => /\/api\/analytics\b/.test(u.pathname);

/** Contain the network. Returns the log so the report can prove what left. */
async function containNetwork(context) {
  const log = { passthroughGets: 0, analyticsSwallowed: 0, writesBlocked: [], external: [], api: [] };
  await context.route('**/*', async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const sameOrigin = url.origin === appUrl;
    const isApi = sameOrigin
      ? url.pathname.startsWith('/api/')
      : url.origin === new URL(apiOrigin).origin;

    if (sameOrigin && !isApi) return route.continue();

    if (isApi) {
      if (isAnalytics(url)) {
        log.analyticsSwallowed += 1;
        return route.fulfill({ status: 204, body: '' });
      }
      if (request.method() === 'GET') {
        try {
          const target = sameOrigin ? `${apiOrigin}${url.pathname}${url.search}` : request.url();
          // A plain server-side read: no browser Origin/Referer is forwarded
          // (the local QA origin is not an allowed app origin), and nothing is
          // spoofed. Public GETs only.
          const response = await route.fetch({
            url: target,
            headers: { accept: request.headers().accept || 'application/json' },
          });
          log.passthroughGets += 1;
          log.api.push(`${response.status()} ${url.pathname}${url.search}`.slice(0, 140));
          return route.fulfill({
            response,
            headers: {
              ...response.headers(),
              'access-control-allow-origin': request.headers().origin || appUrl,
              'access-control-allow-credentials': 'true',
            },
          });
        } catch (e) {
          log.api.push(`ERR ${url.pathname} ${String(e).slice(0, 80)}`);
          return route.fulfill({ status: 503, body: '' });
        }
      }
      if (request.method() === 'OPTIONS') {
        return route.fulfill({
          status: 204,
          headers: {
            'access-control-allow-origin': request.headers().origin || appUrl,
            'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
            'access-control-allow-headers': '*',
            'access-control-allow-credentials': 'true',
          },
          body: '',
        });
      }
      log.writesBlocked.push(`${request.method()} ${url.pathname}`);
      return route.fulfill({
        status: 503,
        headers: { 'access-control-allow-origin': request.headers().origin || appUrl },
        body: '',
      });
    }

    // Fonts/tiles/CDN reads are tolerated as 503 so nothing third-party loads.
    log.external.push(`${request.method()} ${request.url().slice(0, 100)}`);
    return route.fulfill({
      status: 503,
      headers: { 'access-control-allow-origin': appUrl },
      body: '',
    });
  });
  return log;
}

async function waitForApp(page, settleMs = 7000) {
  await page.waitForFunction(
    () => Boolean(document.querySelector('flutter-view') || document.querySelector('flt-glass-pane')),
    { timeout: 90000 },
  );
  await page.waitForTimeout(settleMs);
}

/** Turn on Flutter's accessibility tree so the DOM can be asserted on. */
async function enableSemantics(page) {
  await page.evaluate(() => {
    const el = document.querySelector('flt-semantics-placeholder');
    if (el) el.click();
  });
  await page.waitForTimeout(1200);
}

async function semantics(page) {
  return page.evaluate(() => {
    const nodes = [...document.querySelectorAll('flt-semantics, [flt-semantics-identifier]')];
    return nodes
      .map((n) => ({
        role: n.getAttribute('role') || '',
        label: (n.getAttribute('aria-label') || n.textContent || '').trim().replace(/\s+/g, ' '),
      }))
      .filter((n) => n.label || n.role);
  });
}

const textOf = (tree) => tree.map((n) => n.label).join(' | ');

async function snap(page, name, record) {
  const file = path.join(outDir, `${name}.png`);
  await page.screenshot({ path: file });
  record.screenshots.push(path.relative(rootDir, file).replaceAll('\\', '/'));
}

function check(record, name, ok, detail = '') {
  record.checks.push({ name, ok: Boolean(ok), detail });
  if (!ok) record.failed = true;
}

/** A pre-existing defect the run reports but does not fail on. */
function known(record, name, ok, detail = '') {
  record.known = record.known || [];
  record.known.push({ name, ok: Boolean(ok), detail });
}

/** Slovene is reached the way a visitor reaches it: the locale-prefixed launch URL. */
const isSl = (record) => record.locale.startsWith('sl');
const entityPathFor = (record) =>
  isSl(record) ? `/sl/umetnine/${artworkId}` : `/en/artworks/${artworkId}`;

const pathOf = (page) => new URL(page.url()).pathname;
const trace = async (page, record, step) => {
  record.trace = record.trace || [];
  record.trace.push({ step, path: pathOf(page), history: await historyLength(page) });
};
const historyLength = (page) => page.evaluate(() => history.length);

async function newContext(browserType, browser, { width, scheme, locale }) {
  const isChromium = browserType === 'chromium';
  const context = await browser.newContext({
    viewport: { width, height: width <= 480 ? 844 : 900 },
    deviceScaleFactor: 1,
    colorScheme: scheme,
    locale,
    ...(isChromium && width <= 480 ? { isMobile: true, hasTouch: true } : {}),
  });
  // NOTE: the browser locale does not switch the app language, so QA_LOCALES
  // only varies navigator.language. Slovene strings are covered by l10n tests;
  // a stored-language seed for browser runs has not been identified.
  const network = await containNetwork(context);
  await context.routeWebSocket(/.*/, (ws) => ws.close());
  return { context, network };
}

async function freshEntry(page, route, tag, record) {
  await page.goto(`${appUrl}${route}`, { waitUntil: 'domcontentloaded' });
  await waitForApp(page);
  await snap(page, `${tag}-first-frame`, record);
  await enableSemantics(page);
  const tree = await semantics(page);
  const text = textOf(tree);
  const hits = FORBIDDEN_FIRST_FRAME.filter((rx) => rx.test(text)).map(String);
  check(record, `${tag}: no first-frame modal/alpha/onboarding/permission/wallet text`, hits.length === 0, hits.join(', '));
  check(record, `${tag}: no dialog role in the first frame`, !tree.some((n) => n.role === 'dialog'));
  const where = pathOf(page);
  check(
    record,
    `${tag}: stayed on public discovery, not onboarding or sign-in`,
    !/\/(onboarding|sign-in|register|auth)/.test(where),
    where,
  );
  return { tree, where };
}

async function scenarioFresh(page, tag, record) {
  for (const route of isSl(record) ? ['/sl', '/map'] : ['/', '/main', '/map']) {
    const slug = route === '/' ? 'root' : route.replace(/^[/]/, '').replace(/[/]/g, '-');
    await page.context().clearCookies();
    await page.evaluate(() => { try { localStorage.clear(); sessionStorage.clear(); } catch {} }).catch(() => {});
    await freshEntry(page, route, `${tag}-fresh-${slug}`, record);
  }
}

async function scenarioEntity(page, tag, record) {
  const entityPath = entityPathFor(record);
  await freshEntry(page, entityPath, `${tag}-entity`, record);
  const entered = pathOf(page);
  check(record, `${tag}: public entity URL is kept exactly`, entered === entityPath, entered);
  const historyAtEntry = await historyLength(page);

  await page.goBack({ waitUntil: 'domcontentloaded' }).catch(() => {});
  await page.waitForTimeout(2500);
  await snap(page, `${tag}-entity-back`, record);
  await page.goForward({ waitUntil: 'domcontentloaded' }).catch(() => {});
  await page.waitForTimeout(2500);
  await page.reload({ waitUntil: 'domcontentloaded' });
  await waitForApp(page, 6000);
  await snap(page, `${tag}-entity-reload`, record);
  const afterReload = pathOf(page);
  check(record, `${tag}: refresh stays on the public entity`, afterReload === entityPath, afterReload);
  check(record, `${tag}: no onboarding after refresh`, !/onboarding|sign-in|register/.test(afterReload), afterReload);
  const historyAfter = await historyLength(page);
  check(
    record,
    `${tag}: no duplicate history hops (entry ${historyAtEntry}, after reload ${historyAfter})`,
    // Flutter web pushes one guard entry per document load (and back/forward
    // re-enters one), so a reload may add up to two; more means a route loop.
    historyAfter <= historyAtEntry + 2,
  );
}

async function waitForTree(page, predicate, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (predicate(textOf(await semantics(page)))) return true;
    await page.waitForTimeout(600);
  }
  return false;
}

const SAVE_RX = /\b(save|shrani)\b/i;

async function controlBox(page, rx) {
  for (const role of ['button', 'switch', 'link', 'checkbox']) {
    const control = page.getByRole(role, { name: rx }).first();
    if (await control.count()) return control.boundingBox();
  }
  return null;
}

/** Detail pages build their action row lazily; scroll until the control is on screen. */
async function scrollToControl(page, rx, attempts = 8) {
  for (let i = 0; i <= attempts; i += 1) {
    const tree = await semantics(page);
    if (tree.some((n) => n.role !== 'dialog' && rx.test(n.label) && n.label.length < 40)) {
      const box = await controlBox(page, rx);
      const h = page.viewportSize().height;
      if (box && box.y > 60 && box.y + box.height < h - 90) return true;
    }
    if (i === attempts) break;
    const size = page.viewportSize();
    await page.mouse.move(Math.round(size.width / 2), Math.round(size.height * 0.6));
    await page.mouse.wheel(0, 380);
    await page.waitForTimeout(900);
  }
  return false;
}

async function tapLocator(page, locator) {
  // A real pointer tap at the control's centre: what a visitor does. A DOM
  // click on the semantics node can be swallowed by an overlay.
  await locator.scrollIntoViewIfNeeded({ timeout: 3000 }).catch(() => {});
  const box = await locator.boundingBox();
  if (!box) return false;
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  return true;
}

async function clickByName(page, name) {
  // Prefer the control itself (its role is button/switch/link) over a parent
  // group whose label merely contains the text: a group's centre can sit
  // between its children and miss the control. Fall back to any labelled node.
  for (const role of ['button', 'switch', 'link', 'checkbox']) {
    const control = page.getByRole(role, { name }).first();
    if (await control.count()) return tapLocator(page, control);
  }
  const labelled = page.getByLabel(name).first();
  if (await labelled.count()) return tapLocator(page, labelled);
  const byText = page.locator('flt-semantics').filter({ hasText: name }).first();
  if (await byText.count()) return tapLocator(page, byText);
  return false;
}

async function scenarioAction(page, tag, record) {
  const entityPath = entityPathFor(record);
  await freshEntry(page, entityPath, `${tag}-action`, record);
  if (isSl(record)) {
    const slText = textOf(await semantics(page));
    check(record, `${tag}: the entity renders in Slovene`, /(shrani|všeč|komentar|prikaži na zemljevidu)/i.test(slText), slText.slice(0, 160));
  }

  const found = await scrollToControl(page, SAVE_RX);
  const clicked = found && (await clickByName(page, SAVE_RX));
  await page.waitForTimeout(1800);
  await snap(page, `${tag}-action-sheet`, record);
  if (!clicked) {
    check(record, `${tag}: Save control found in the semantics tree`, false, 'artwork may not have loaded');
    return;
  }
  let tree = await semantics(page);
  let text = textOf(tree);
  check(record, `${tag}: Save opens the contextual activation sheet`, /continue with email|nadaljuj z e-po/i.test(text), text.slice(0, 160));
  check(record, `${tag}: sheet is not a role picker or wallet ask`, !/choose your role|connect (your )?wallet/i.test(text));

  // Dismiss: nothing mutates, the entity stays.
  await page.keyboard.press('Escape');
  await page.waitForTimeout(1200);
  const afterDismiss = pathOf(page);
  check(record, `${tag}: dismissing returns to the same entity`, afterDismiss === entityPath, afterDismiss);

  // Retry the same action: the gate offers itself again.
  await trace(page, record, 'after dismiss');
  await clickByName(page, SAVE_RX);
  await page.waitForTimeout(1500);
  tree = await semantics(page);
  check(record, `${tag}: retry offers the sheet again`, /continue with email|nadaljuj z e-po/i.test(textOf(tree)));

  // Continue with email enters the account step, scoped to the account.
  const entered = await clickByName(page, /continue with email/i) || await clickByName(page, /nadaljuj z e-po/i);
  const left = entered && (await waitForTree(page, (t) => !/not now|ne zdaj/i.test(t), 12000));
  await trace(page, record, 'account step');
  await snap(page, `${tag}-action-account-step`, record);
  check(record, `${tag}: Continue with email leaves the sheet for the account step`, left);
  if (left) {
    tree = await semantics(page);
    text = textOf(tree);
    check(record, `${tag}: account step does not lead with role or wallet`, !/choose your role|izberi svojo vlogo|connect (your )?wallet/i.test(text), text.slice(0, 160));
    await page.goBack({ waitUntil: 'domcontentloaded' }).catch(() => {});
    await page.waitForTimeout(3000);
    await page.waitForTimeout(2500);
    const back = pathOf(page);
    await snap(page, `${tag}-action-back-to-entity`, record);
    record.notes = { ...(record.notes || {}), afterBack: { path: back, history: await historyLength(page) } };
    // The gate pushes the named `/onboarding` route and the entity beneath it
    // is unnamed, so the address bar used to keep `/onboarding` after Back.
    // UrlCoherenceObserver now restores the URL of the visible page.
    check(record, `${tag}: address bar returns to the entity after Back`, back === entityPath, back);
    const treeAfterBack = textOf(await semantics(page));
    check(record, `${tag}: Back from the account step shows the entity, not onboarding`, !/create an account|sign in/i.test(treeAfterBack.slice(0, 200)) || /najemni/i.test(treeAfterBack), treeAfterBack.slice(0, 120));
    // The address bar must agree with what is on screen: a refresh here must
    // land on the entity, not re-open the account step.
    await page.reload({ waitUntil: 'domcontentloaded' });
    await waitForApp(page, 6000);
    const afterReload = pathOf(page);
    await snap(page, `${tag}-action-back-then-reload`, record);
    // With the stale address bar a refresh used to open the first-run welcome
    // wall. It must now land in public discovery or on the entity.
    const reloadText = textOf(await semantics(page).catch(() => []));
    check(record, `${tag}: refresh after Back shows no welcome wall`, !/choose one path|get started/i.test(reloadText), afterReload);
    check(record, `${tag}: refresh after Back returns to the entity`, afterReload === entityPath, afterReload);
  }
}

async function scenarioExplicit(page, tag, record) {
  // A bare /onboarding (stale address bar, typed URL, refresh that dropped its
  // arguments) is not an acquisition entry: it must land in public discovery.
  await page.goto(`${appUrl}/onboarding`, { waitUntil: 'domcontentloaded' });
  await waitForApp(page, 7000);
  await snap(page, `${tag}-explicit-bare-onboarding`, record);
  await enableSemantics(page);
  const bareText = textOf(await semantics(page));
  check(record, `${tag}: bare /onboarding shows no first-visit welcome wall`, !/choose one path|get started/i.test(bareText), bareText.slice(0, 140));

  for (const route of ['/register', '/sign-in']) {
    await page.goto(`${appUrl}${route}`, { waitUntil: 'domcontentloaded' });
    await waitForApp(page, 6000);
    await snap(page, `${tag}-explicit-${route.slice(1)}`, record);
    await enableSemantics(page);
    const tree = await semantics(page);
    const where = pathOf(page);
    check(record, `${tag}: ${route} stays an explicit account route`, where.startsWith(route), where);
    check(
      record,
      `${tag}: ${route} shows account methods`,
      /email|google|wallet|sign in|prijava|e-po/i.test(textOf(tree)),
      textOf(tree).slice(0, 140),
    );
  }

  // These routes resolve straight to their screen without AppInitializer, so
  // the launch language must be applied at provider creation: `?lang=sl` has
  // to produce Slovene here, not English.
  await page.goto(`${appUrl}/register?lang=sl`, { waitUntil: 'domcontentloaded' });
  await waitForApp(page, 6000);
  await enableSemantics(page);
  const slText = textOf(await semantics(page));
  check(
    record,
    `${tag}: /register?lang=sl renders Slovene, not English`,
    /ustvari račun|nadaljuj|denarnic/i.test(slText) && !/create your account/i.test(slText),
    slText.slice(0, 140),
  );
}

const RUNNERS = { fresh: scenarioFresh, entity: scenarioEntity, action: scenarioAction, explicit: scenarioExplicit };

async function main() {
  await fs.mkdir(outDir, { recursive: true });
  const server = await startServer();
  const manifest = { label, appUrl, startedAt: new Date().toISOString(), runs: [] };
  const types = { chromium, firefox };

  try {
    for (const browserType of browsers) {
      const browser = await types[browserType].launch({ headless: true });
      try {
        for (const width of widths) {
          for (const scheme of schemes) {
            for (const locale of locales) {
              // Keep the matrix tractable: the full scheme/locale cross is
              // taken at one phone width and desktop; 320 is light/en only.
              if (width === 320 && (scheme !== 'light' || locale !== 'en-US')) continue;
              const tag = `${browserType}-${width}-${scheme}-${locale.slice(0, 2)}`;
              const { context, network } = await newContext(browserType, browser, { width, scheme, locale });
              const page = await context.newPage();
              const record = { tag, browser: browserType, width, scheme, locale, checks: [], screenshots: [], failed: false, errors: [] };
              page.on('pageerror', (e) => record.errors.push(String(e).slice(0, 200)));
              for (const name of scenarios) {
                try {
                  await RUNNERS[name](page, tag, record);
                } catch (e) {
                  check(record, `${tag}: scenario ${name} completed`, false, String(e).slice(0, 240));
                }
              }
              record.network = {
                passthroughGets: network.passthroughGets,
                analyticsSwallowed: network.analyticsSwallowed,
                writesBlocked: network.writesBlocked.slice(0, 10),
                externalBlocked: network.external.length,
                apiSample: network.api.slice(0, 40),
              };
              manifest.runs.push(record);
              console.log(`${record.failed ? 'FAIL' : 'ok  '} ${tag} (${record.checks.length} checks)`);
              for (const c of record.checks.filter((x) => !x.ok)) console.log(`     - ${c.name} ${c.detail}`);
              for (const k of (record.known || []).filter((x) => !x.ok)) console.log(`     ~ known: ${k.name} ${k.detail}`);
              await context.close();
            }
          }
        }
      } finally {
        await browser.close();
      }
    }
  } finally {
    server.close();
    manifest.finishedAt = new Date().toISOString();
    manifest.failed = manifest.runs.filter((r) => r.failed).length;
    await fs.writeFile(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
  }
  console.log(`\n${manifest.runs.length} runs, ${manifest.failed} with failures -> ${path.relative(rootDir, outDir)}`);
  process.exitCode = manifest.failed ? 1 : 0;
}

await main();
