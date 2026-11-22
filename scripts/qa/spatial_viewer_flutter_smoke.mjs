// Browser smoke for the Flutter web spatial viewer: the built widget, in a real browser.
//
// Serves a release build of tool/qa/spatial_viewer_web_harness_main.dart (the real
// ArtworkSpatialArchiveSection, ArtworkProvider and bundled Spark viewer) from a local static server
// that sends the same CSP header web/.htaccess sends for HTML. The backend is mocked at the network
// layer: `GET /api/artworks/<id>/spatial` returns a fixture history and `GET /api/upload/file/<cid>`
// the synthetic sample splat / manifest. Nothing reaches a real backend and no artist data is used.
//
//   flutter build web --release -t tool/qa/spatial_viewer_web_harness_main.dart --output build/spatial-harness
//   node scripts/qa/spatial_viewer_flutter_smoke.mjs
//
// Environment:
//   HARNESS_ROOT  build directory (default build/spatial-harness)
//   BROWSERS      comma list (default chromium)
//   QA_OUT        output directory (default output/playwright/artifacts/spatial-viewer-flutter)
//   LAYOUTS       comma list of layouts to run: desktop, mobile (default both)
// Exits non-zero on any failed check.
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { createRequire } from 'node:module';

const { chromium, firefox } = createRequire(import.meta.url)('playwright');

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const HARNESS_ROOT = path.resolve(process.env.HARNESS_ROOT || path.join(ROOT, 'build', 'spatial-harness'));
const OUT = path.resolve(process.env.QA_OUT || path.join(ROOT, 'output', 'playwright', 'artifacts', 'spatial-viewer-flutter'));
const BROWSERS = (process.env.BROWSERS || 'chromium').split(',').map((s) => s.trim()).filter(Boolean);
const LAYOUTS = (process.env.LAYOUTS || 'desktop,mobile').split(',').map((s) => s.trim()).filter(Boolean);
const SAMPLE = fs.readFileSync(path.join(ROOT, 'test', 'fixtures', 'spatial', 'sample_flower.splat'));
fs.mkdirSync(OUT, { recursive: true });

const ARTWORK_ID = '53b99c8b-8503-545c-8a13-55f60cfb8342';
const htaccess = fs.readFileSync(path.join(ROOT, 'web', '.htaccess'), 'utf8');
const HTML_CSP = /Header set Content-Security-Policy "([^"]+)"/.exec(htaccess)?.[1];
if (!HTML_CSP) throw new Error('could not read the HTML CSP from web/.htaccess');
if (!fs.existsSync(path.join(HARNESS_ROOT, 'index.html'))) {
  throw new Error(`no harness build at ${HARNESS_ROOT}; build it first (see the header of this file)`);
}

const UPRIGHT = { matrix: [0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1], matrixOrder: 'column-major' };
const CORS = { 'access-control-allow-origin': '*', 'cache-control': 'no-store' };

const variant = (role, cid, format, sizeBytes) => ({
  role, cid, uri: `ipfs://${cid}`, sizeBytes, storageClass: role === 'spatial_archive' ? 'cold' : 'warm',
  mimeType: 'application/octet-stream', format,
});
const HISTORY = {
  success: true,
  data: {
    current: null,
    history: [{
      id: 'spatial-fixture-1', artworkId: ARTWORK_ID, markerId: null,
      capturedAt: '2026-11-07T10:00:00.000Z', capturedBy: null, publishedAt: '2026-11-22T10:00:00.000Z',
      version: 1, canonicalManifestCid: 'bafy-manifest', canonicalRecordCid: 'bafy-record', isCurrent: true,
      variants: [
        { role: 'spatial_manifest', cid: 'bafy-manifest', uri: 'ipfs://bafy-manifest', sizeBytes: 400, storageClass: 'hot', mimeType: 'application/json', format: 'json' },
        variant('spatial_mobile', 'bafy-sample', 'splat', SAMPLE.length),
        variant('spatial_archive', 'bafy-archive', 'ply', 9_000_000),
      ],
    }],
  },
};
HISTORY.data.current = HISTORY.data.history[0];
const EMPTY = { success: true, data: { current: null, history: [] } };

// A history whose current capture carries exactly these public variants (plus the manifest).
function historyWith(variants) {
  const capture = { ...HISTORY.data.history[0], variants: [HISTORY.data.history[0].variants[0], ...variants] };
  return { success: true, data: { current: capture, history: [capture] } };
}

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.ico': 'image/x-icon', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.svg': 'image/svg+xml', '.css': 'text/css', '.map': 'application/json',
};

function startServer() {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://x');
    let file = path.join(HARNESS_ROOT, decodeURIComponent(url.pathname));
    if (!file.startsWith(HARNESS_ROOT)) { res.writeHead(403); return res.end(); }
    if (url.pathname === '/' || !fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(HARNESS_ROOT, 'index.html');
    const headers = { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' };
    if (file.endsWith('.html')) headers['content-security-policy'] = HTML_CSP;
    res.writeHead(200, headers);
    res.end(fs.readFileSync(file));
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port })));
}

const failures = [];
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` - ${detail}` : ''}`);
  if (!ok) failures.push(name);
};

async function colourStats(page, png) {
  return page.evaluate(async (b64) => {
    const image = new Image();
    await new Promise((resolve, reject) => { image.onload = resolve; image.onerror = reject; image.src = `data:image/png;base64,${b64}`; });
    const canvas = document.createElement('canvas');
    canvas.width = image.naturalWidth; canvas.height = image.naturalHeight;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(image, 0, 0);
    const { data, width, height } = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const groups = { red: { n: 0, y: 0 }, green: { n: 0, y: 0 } };
    let minX = width; let maxX = 0; let minY = height; let maxY = 0;
    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) {
        const i = (y * width + x) * 4;
        const [r, g, b] = [data[i], data[i + 1], data[i + 2]];
        const isRed = r > 170 && g < 110 && b < 120;
        const isGreen = g > 120 && r < 120 && b < 130 && g - r > 40;
        const group = isRed ? groups.red : isGreen ? groups.green : null;
        if (!group) continue;
        group.n += 1; group.y += y;
        minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      }
    }
    return {
      redN: groups.red.n, greenN: groups.green.n,
      redY: groups.red.n ? groups.red.y / groups.red.n : null, greenY: groups.green.n ? groups.green.y / groups.green.n : null,
      width: maxX - minX, height: maxY - minY,
    };
  }, png.toString('base64'));
}

async function newScenario(browser, { origin, viewport, reducedMotion, hasTouch = false, history = HISTORY, bytesOk = true, manifest = true }) {
  const context = await browser.newContext({ locale: 'en-US', viewport, hasTouch, reducedMotion: reducedMotion ? 'reduce' : 'no-preference' });
  await context.addInitScript(() => { Error.stackTraceLimit = 60; });
  const seen = { upload: [], history: 0, other: [], gateway: [] };
  await context.route((u) => u.origin !== origin, async (route) => {
    const url = new URL(route.request().url());
    if (/\/api\/artworks\/[^/]+\/spatial$/.test(url.pathname)) {
      seen.history += 1;
      return route.fulfill({ status: 200, headers: { ...CORS, 'content-type': 'application/json' }, body: JSON.stringify(history) });
    }
    const m = /\/api\/upload\/file\/([^/]+)$/.exec(url.pathname);
    if (m) {
      seen.upload.push(m[1]);
      if (m[1] === 'bafy-sample' && bytesOk) return route.fulfill({ status: 200, headers: { ...CORS, 'content-type': 'application/octet-stream' }, body: SAMPLE });
      if (m[1] === 'bafy-manifest' && manifest) return route.fulfill({ status: 200, headers: { ...CORS, 'content-type': 'application/json' }, body: JSON.stringify({ schema: 'kubus.spatial/1', transform: UPRIGHT }) });
      return route.fulfill({ status: 404, headers: CORS, body: '' });
    }
    // Public IPFS gateways are not a route for the public viewer (they have no withdrawal gate); any contact is a failure.
    if (/(^|\.)(dweb\.link|ipfs\.io|pinata\.cloud|cloudflare-ipfs\.com|w3s\.link|nftstorage\.link|gateway\.pinata\.cloud)$/.test(url.hostname)) { seen.gateway.push(url.hostname); return route.fulfill({ status: 404, headers: CORS, body: '' }); }
    // The Google Identity script the sign-in plugin injects at startup is a live third-party page: it is stubbed so
    // the run does not depend on it (CanvasKit and fonts still come from the real network, see below; the real script can call the plugin's onGoogleLibraryLoad twice, which surfaces as an
    // uncaught StateError "Future already completed" from google_sign_in_web's loadWebSdk, unrelated to the viewer).
    if (url.hostname === 'accounts.google.com') return route.fulfill({ status: 200, headers: { ...CORS, 'content-type': 'text/javascript' }, body: '/* stubbed in the spatial viewer smoke */' });
    // Fonts / canvaskit CDN etc.: NOT stubbed, the run needs internet access; let the real network answer; any other API call is refused.
    if (/\/api\//.test(url.pathname)) { seen.other.push(url.pathname); return route.fulfill({ status: 404, headers: CORS, body: '' }); }
    return route.continue();
  });
  const page = await context.newPage();
  const problems = [];
  page.on('console', (m) => { if (/Content Security Policy|violates/i.test(m.text())) problems.push(m.text()); });
  page.on('pageerror', (e) => problems.push(`pageerror: ${e.message} ${String(e.stack || '').split(String.fromCharCode(10)).slice(0, 40).join(' / ')}`));
  return { context, page, seen, problems };
}

const viewerFrame = (page) => page.frames().find((f) => f.url().includes('spatial_viewer/index.html'));
async function viewerState(page) {
  const frame = viewerFrame(page);
  if (!frame) return null;
  return frame.evaluate(() => ({ ...window.__spatialDebug(), statusHidden: document.querySelector('#status').hidden, status: document.querySelector('#status').textContent })).catch(() => null);
}
async function waitFor(fn, timeout = 60000) {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    const value = await fn();
    if (value) return value;
    await new Promise((r) => setTimeout(r, 250));
  }
  return null;
}

async function run(browserType, name) {
  const browser = await browserType.launch({ args: name === 'chromium' ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] : [] });
  const { server, port } = await startServer();
  const origin = `http://127.0.0.1:${port}`;
  try {
    for (const layout of [
      { id: 'desktop', viewport: { width: 1280, height: 900 }, reducedMotion: true },
      { id: 'mobile', viewport: { width: 390, height: 844 }, reducedMotion: false, hasTouch: true },
    ].filter((l) => LAYOUTS.includes(l.id))) {
      const tag = `${name}/${layout.id}`;

      // A. In view: loads at once, upright through the manifest transform, orbit works, archive untouched.
      {
        const s = await newScenario(browser, { origin, ...layout });
        await s.page.goto(`${origin}/?spacer=0`);
        const ready = await waitFor(async () => {
          const st = await viewerState(s.page);
          return st && st.hasMesh && st.statusHidden ? st : null;
        });
        check(`${tag}: inline viewer loads the published splat`, !!ready, JSON.stringify(ready));
        check(`${tag}: history requested once`, s.seen.history >= 1, `${s.seen.history}`);
        check(`${tag}: bytes come from /api/upload/file, never the archive tier`, s.seen.upload.includes('bafy-sample') && !s.seen.upload.includes('bafy-archive'), s.seen.upload.join(','));
        check(`${tag}: manifest read for the transform`, s.seen.upload.includes('bafy-manifest'));
        const m = ready?.matrix || [];
        check(`${tag}: manifest transform.matrix reached the mesh`, m.length === 16 && Math.abs(m[1] - 1) < 1e-6 && Math.abs(m[4] + 1) < 1e-6, JSON.stringify(m));
        await s.page.waitForTimeout(1500);
        const frameEl = s.page.locator('iframe[title="Spatial archive"]');
        check(`${tag}: one viewer iframe in the page`, (await frameEl.count()) === 1, `${await frameEl.count()}`);
        const shot = await frameEl.screenshot();
        fs.writeFileSync(path.join(OUT, `${tag.replace('/', '-')}-inline.png`), shot);
        const stats = await colourStats(s.page, shot);
        check(`${tag}: piece is visible and stands upright with the head on top`, stats.redN > 100 && stats.greenN > 50 && stats.height > stats.width && stats.redY < stats.greenY, JSON.stringify(stats));
        check(`${tag}: iframe is shown once the viewer is ready`, (await frameEl.evaluate((el) => getComputedStyle(el).visibility)) === 'visible');
        const box = await frameEl.boundingBox();
        check(`${tag}: viewer fits the viewport width`, box.width <= layout.viewport.width && box.width > 200, `${Math.round(box.width)}x${Math.round(box.height)}`);
        const pointerEvents = () => frameEl.evaluate((el) => getComputedStyle(el).pointerEvents);
        const centre = { x: box.x + box.width / 2, y: box.y + box.height / 2 };
        check(`${tag}: the viewer starts inert so the page keeps its scroll`, (await pointerEvents()) === 'none');

        // Activation: a tap hands the viewer every gesture; Escape, a tap outside and Done hand them back.
        await s.page.mouse.click(centre.x, centre.y);
        check(`${tag}: tapping the viewer activates it`, (await waitFor(async () => ((await pointerEvents()) === 'auto' ? true : null), 10000)) === true);
        check(`${tag}: the viewer keeps its height while active (no row squeezes it)`, Math.abs((await frameEl.boundingBox()).height - box.height) < 2, `${Math.round(box.height)} -> ${Math.round((await frameEl.boundingBox()).height)}`);
        const before = await viewerState(s.page);
        if (layout.hasTouch && name === 'chromium') {
          // A touch layout orbits with a finger: a horizontal drag yaws and a vertical one pitches.
          const cdp = await s.context.newCDPSession(s.page);
          const drag = async (dx, dy) => {
            await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: centre.x, y: centre.y }] });
            for (let i = 1; i <= 10; i += 1) {
              await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: centre.x + (dx * i) / 10, y: centre.y + (dy * i) / 10 }] });
              await s.page.waitForTimeout(16);
            }
            await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
          };
          await s.page.waitForTimeout(800);
          await drag(90, 0);
          const mid = await viewerState(s.page);
          check(`${tag}: a horizontal finger drag orbits through the Flutter platform view once activated`, Math.abs(mid.yaw - before.yaw) > 0.3, `${before.yaw.toFixed(2)} -> ${mid.yaw.toFixed(2)}`);
          await drag(0, 100);
          const end = await viewerState(s.page);
          check(`${tag}: a vertical finger drag pitches the camera on the active viewer`, Math.abs(end.pitch - mid.pitch) > 0.4, `${mid.pitch.toFixed(2)} -> ${end.pitch.toFixed(2)}`);
        } else {
          await s.page.mouse.move(centre.x, centre.y);
          await s.page.mouse.down();
          await s.page.mouse.move(centre.x + 90, centre.y + 10, { steps: 6 });
          await s.page.mouse.up();
          const after = await viewerState(s.page);
          check(`${tag}: drag orbits through the Flutter platform view once activated`, Math.abs(after.yaw - before.yaw) > 0.3, `${before.yaw.toFixed(2)} -> ${after.yaw.toFixed(2)}`);
        }
        await s.page.keyboard.press('Escape');
        check(`${tag}: Escape in the active viewer makes it inert again`, (await waitFor(async () => ((await pointerEvents()) === 'none' ? true : null), 10000)) === true);
        // The relayed Escape belongs to the host that asked for it; the inline viewer's host asked for nothing, so nothing closes.
        await s.page.waitForTimeout(500);
        check(`${tag}: Escape in the inline viewer leaves the page and its viewer in place`, (await s.page.locator('iframe').count()) === 1 && (await frameEl.boundingBox())?.width > 200 && s.page.url().startsWith(origin), s.page.url());
        await s.page.mouse.click(centre.x, centre.y);
        await waitFor(async () => ((await pointerEvents()) === 'auto' ? true : null), 10000);
        await s.page.mouse.click(3, 3);
        check(`${tag}: a tap outside the viewer makes it inert again`, (await waitFor(async () => ((await pointerEvents()) === 'none' ? true : null), 10000)) === true);

        await s.page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
        await s.page.mouse.click(centre.x, centre.y);
        await waitFor(async () => ((await pointerEvents()) === 'auto' ? true : null), 10000);
        await s.page.getByRole('button', { name: 'Done' }).click();
        check(`${tag}: the Done button makes the active viewer inert again`, (await waitFor(async () => ((await pointerEvents()) === 'none' ? true : null), 10000)) === true);

        // Page scroll must cross the inert viewer: wheel, and (mobile layout) a touch swipe starting on it.
        const top0 = (await frameEl.boundingBox()).y;
        await s.page.mouse.move(centre.x, centre.y);
        for (let i = 0; i < 3; i += 1) { await s.page.mouse.wheel(0, 50); await s.page.waitForTimeout(80); }
        await s.page.waitForTimeout(400);
        const top1 = (await frameEl.boundingBox()).y;
        check(`${tag}: wheel over the inert viewer scrolls the page (${Math.round(top0)} -> ${Math.round(top1)})`, top0 - top1 > 60);
        if (layout.hasTouch && name === 'chromium') {
          const cdp = await s.context.newCDPSession(s.page);
          const y0 = (await frameEl.boundingBox()).y;
          const startY = Math.min(y0 + 150, layout.viewport.height - 60);
          const touchX = centre.x;
          await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: touchX, y: startY }] });
          for (let i = 1; i <= 8; i += 1) {
            await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: touchX, y: startY - (i * 10) }] });
            await s.page.waitForTimeout(16);
          }
          await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
          await s.page.waitForTimeout(600);
          const y1 = (await frameEl.boundingBox()).y;
          check(`${tag}: a touch swipe that starts on the inert viewer scrolls the page (${Math.round(y0)} -> ${Math.round(y1)})`, y0 - y1 > 30);
        }
        check(`${tag}: no CSP violation or page error`, s.problems.length === 0, s.problems.join(' | '));
        check(`${tag}: no public gateway is contacted`, s.seen.gateway.length === 0, s.seen.gateway.join(','));
        const label = await viewerFrame(s.page).evaluate(() => document.querySelector('canvas').getAttribute('aria-label'));
        check(`${tag}: the canvas carries the app's localized label`, label === 'Spatial archive' || /spatial/i.test(label || ''), String(label));
        await s.context.close();
      }

      // B. Below the fold: nothing is fetched until it scrolls into view.
      {
        const s = await newScenario(browser, { origin, ...layout });
        await s.page.goto(`${origin}/?spacer=2400`);
        await waitFor(async () => (s.seen.history >= 1 ? true : null), 30000);
        await s.page.waitForTimeout(2500);
        check(`${tag}: below the fold, no splat bytes are requested`, s.seen.upload.length === 0 && !viewerFrame(s.page), s.seen.upload.join(','));
        await s.page.mouse.move(layout.viewport.width / 2, layout.viewport.height / 2);
        for (let i = 0; i < 14; i += 1) { await s.page.mouse.wheel(0, 250); await s.page.waitForTimeout(120); }
        const ready = await waitFor(async () => {
          const st = await viewerState(s.page);
          return st && st.hasMesh && st.statusHidden ? st : null;
        });
        check(`${tag}: scrolling it into view loads the splat`, !!ready && s.seen.upload.includes('bafy-sample'), s.seen.upload.join(','));
        await s.context.close();
      }

      // C. Failure: bytes unreachable on every route ends in the failure state, no archive request.
      {
        const s = await newScenario(browser, { origin, ...layout, bytesOk: false });
        await s.page.goto(`${origin}/?spacer=0`);
        await s.page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30000 });
        await s.page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
        const retry = s.page.getByRole('button', { name: 'Try again' });
        const failed = await retry.waitFor({ timeout: 60000 }).then(() => true, () => false);
        check(`${tag}: unreachable bytes end in the Flutter failure notice (Try again offered)`, failed);
        // A final failure empties the iframe so a stalled page stops downloading.
        const emptied = await waitFor(async () => ((await s.page.locator('iframe').getAttribute('src')) === 'about:blank' ? true : null), 10000);
        check(`${tag}: a failed viewer is emptied (about:blank) and hidden`, !!emptied && (await s.page.locator('iframe').evaluate((el) => getComputedStyle(el).visibility)) === 'hidden');
        check(`${tag}: failure never falls back to the archive tier`, !s.seen.upload.includes('bafy-archive'), s.seen.upload.join(','));
        check(`${tag}: failure never contacts a public gateway`, s.seen.gateway.length === 0, s.seen.gateway.join(','));
        fs.writeFileSync(path.join(OUT, `${tag.replace('/', '-')}-failure.png`), await s.page.screenshot());
        await s.context.close();
      }

      // E. "View in 3D" opens the fullscreen dialog with one viewer (the inline one is suspended).
      {
        const s = await newScenario(browser, { origin, ...layout });
        await s.page.goto(`${origin}/?spacer=0`);
        await waitFor(async () => {
          const st = await viewerState(s.page);
          return st && st.hasMesh && st.statusHidden ? st : null;
        });
        await s.page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
        const button = s.page.getByRole('button', { name: 'View in 3D' });
        await button.waitFor({ timeout: 20000 });
        await button.click();
        const opened = await waitFor(async () => {
          const st = await viewerState(s.page);
          const dialog = await s.page.getByRole('button', { name: 'Close' }).count().catch(() => 0);
          return st && st.hasMesh && st.statusHidden && (await s.page.locator('iframe').count()) === 1 ? { st, dialog } : null;
        });
        check(`${tag}: View in 3D opens a single fullscreen viewer and loads it`, !!opened, JSON.stringify(opened));
        // The inline iframe is torn down while the dialog's mounts: wait for the dialog's one to fill the window.
        const fills = (b) => !!b && b.width >= layout.viewport.width - 4 && b.height > layout.viewport.height * 0.6;
        const frameBox = await waitFor(async () => {
          if ((await s.page.locator('iframe').count()) !== 1) return null;
          const b = await s.page.locator('iframe').boundingBox().catch(() => null);
          return fills(b) ? b : null;
        }, 20000);
        check(`${tag}: fullscreen viewer fills the window`, !!frameBox, JSON.stringify(frameBox));
        check(`${tag}: the fullscreen viewer, with no page scroll to protect, is interactive at once`, (await s.page.locator('iframe').evaluate((el) => getComputedStyle(el).pointerEvents)) === 'auto');
        fs.writeFileSync(path.join(OUT, `${tag.replace('/', '-')}-fullscreen.png`), await s.page.screenshot());
        // Escape pressed while the viewer iframe has focus never reaches Flutter: the viewer relays it and the dialog closes.
        const fullBox = await s.page.locator('iframe').boundingBox();
        await s.page.mouse.click(fullBox.x + fullBox.width / 2, fullBox.y + fullBox.height / 2);
        await s.page.keyboard.press('Escape');
        const closed = await waitFor(async () => {
          if ((await s.page.locator('iframe').count()) !== 1) return null;
          const b = await s.page.locator('iframe').boundingBox().catch(() => null);
          return b && !fills(b) ? b : null;
        }, 20000);
        check(`${tag}: Escape inside the fullscreen viewer closes the dialog`, !!closed, JSON.stringify(closed));
        await s.context.close();
      }

      // F. The optimised tier fails to load: the preview tier is tried next (no gateway, no archive).
      {
        const history = historyWith([
          variant('spatial_mobile', 'bafy-bad', 'splat', 1000),
          variant('spatial_preview', 'bafy-sample', 'splat', SAMPLE.length),
          variant('spatial_archive', 'bafy-archive', 'ply', 9_000_000),
        ]);
        const s = await newScenario(browser, { origin, ...layout, history });
        await s.page.goto(`${origin}/?spacer=0`);
        const ready = await waitFor(async () => {
          const st = await viewerState(s.page);
          return st && st.hasMesh && st.statusHidden ? st : null;
        }, 90000);
        const order = s.seen.upload.filter((cid) => cid === 'bafy-bad' || cid === 'bafy-sample');
        check(`${tag}: a failing optimised tier falls back to the preview tier`, !!ready && order[0] === 'bafy-bad' && order.includes('bafy-sample'), `${order.join(',')} ${JSON.stringify(ready)}`);
        check(`${tag}: tier fallback never touches the archive or a gateway`, !s.seen.upload.includes('bafy-archive') && s.seen.gateway.length === 0, s.seen.upload.join(','));
        await s.context.close();
      }

      // G. A large archive shows its size and asks before it downloads.
      {
        const history = historyWith([
          variant('spatial_mobile', 'bafy-sample', 'splat', SAMPLE.length),
          variant('spatial_archive', 'bafy-archive', 'ply', 300 * 1024 * 1024),
        ]);
        const s = await newScenario(browser, { origin, ...layout, history });
        await s.page.goto(`${origin}/?spacer=0`);
        await waitFor(async () => {
          const st = await viewerState(s.page);
          return st && st.hasMesh && st.statusHidden ? st : null;
        });
        await s.page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
        const offer = s.page.getByRole('button', { name: 'Load archival quality (300 MB)' });
        await offer.waitFor({ timeout: 20000 });
        check(`${tag}: the archive button states the archive size`, (await offer.count()) === 1);
        await offer.click();
        await s.page.getByText('Load a large archive?').waitFor({ timeout: 20000 });
        check(`${tag}: a large archive asks for confirmation`, true);
        await s.page.getByRole('button', { name: 'Cancel' }).click();
        await s.page.waitForTimeout(1500);
        check(`${tag}: declining the confirmation downloads nothing`, !s.seen.upload.includes('bafy-archive'), s.seen.upload.join(','));
        await s.page.getByRole('button', { name: 'Load archival quality (300 MB)' }).click();
        await s.page.getByRole('button', { name: 'Continue' }).click();
        const asked = await waitFor(async () => (s.seen.upload.includes('bafy-archive') ? true : null), 30000);
        check(`${tag}: confirming starts the archive download`, !!asked, s.seen.upload.join(','));
        await s.context.close();
      }

      // D. Empty public history: no viewer at all.
      {
        const s = await newScenario(browser, { origin, ...layout, history: EMPTY });
        await s.page.goto(`${origin}/?spacer=0`);
        await waitFor(async () => (s.seen.history >= 1 ? true : null), 30000);
        await s.page.waitForTimeout(1500);
        check(`${tag}: empty public history shows no viewer and fetches no bytes`, !viewerFrame(s.page) && s.seen.upload.length === 0 && (await s.page.locator('iframe').count()) === 0);
        await s.context.close();
      }
    }
  } finally {
    await browser.close();
    server.close();
  }
}

for (const name of BROWSERS) {
  await run(name === 'firefox' ? firefox : chromium, name);
}
if (failures.length) {
  console.error(`\n${failures.length} check(s) failed`);
  process.exit(1);
}
console.log('\nAll Flutter spatial viewer checks passed');
