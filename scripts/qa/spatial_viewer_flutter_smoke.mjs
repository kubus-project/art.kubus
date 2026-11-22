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

async function newScenario(browser, { origin, viewport, reducedMotion, history = HISTORY, bytesOk = true, manifest = true }) {
  const context = await browser.newContext({ locale: 'en-US', viewport, reducedMotion: reducedMotion ? 'reduce' : 'no-preference' });
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
    // Public IPFS gateways are fallbacks only; the smoke never contacts them.
    if (/(^|\.)(dweb\.link|ipfs\.io|pinata\.cloud)$/.test(url.hostname)) { seen.gateway.push(url.hostname); return route.fulfill({ status: 404, headers: CORS, body: '' }); }
    // Fonts / canvaskit CDN etc.: let the real network answer; any other API call is refused.
    if (/\/api\//.test(url.pathname)) { seen.other.push(url.pathname); return route.fulfill({ status: 404, headers: CORS, body: '' }); }
    return route.continue();
  });
  const page = await context.newPage();
  const problems = [];
  page.on('console', (m) => { if (/Content Security Policy|violates/i.test(m.text())) problems.push(m.text()); });
  page.on('pageerror', (e) => problems.push(`pageerror: ${e.message} ${String(e.stack || '').split(String.fromCharCode(10)).slice(0, 4).join(' / ')}`));
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
      { id: 'mobile', viewport: { width: 390, height: 844 }, reducedMotion: false },
    ]) {
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
        const frameEl = s.page.locator('iframe[title="Interactive spatial archive"]');
        check(`${tag}: one viewer iframe in the page`, (await frameEl.count()) === 1, `${await frameEl.count()}`);
        const shot = await frameEl.screenshot();
        fs.writeFileSync(path.join(OUT, `${tag.replace('/', '-')}-inline.png`), shot);
        const stats = await colourStats(s.page, shot);
        check(`${tag}: piece is visible and stands upright with the head on top`, stats.redN > 100 && stats.greenN > 50 && stats.height > stats.width && stats.redY < stats.greenY, JSON.stringify(stats));
        check(`${tag}: iframe is shown once the viewer is ready`, (await frameEl.evaluate((el) => getComputedStyle(el).visibility)) === 'visible');
        const box = await frameEl.boundingBox();
        check(`${tag}: viewer fits the viewport width`, box.width <= layout.viewport.width && box.width > 200, `${Math.round(box.width)}x${Math.round(box.height)}`);
        const before = await viewerState(s.page);
        await s.page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
        await s.page.mouse.down();
        await s.page.mouse.move(box.x + box.width / 2 + 90, box.y + box.height / 2 + 10, { steps: 6 });
        await s.page.mouse.up();
        const after = await viewerState(s.page);
        check(`${tag}: drag orbits through the Flutter platform view`, Math.abs(after.yaw - before.yaw) > 0.3, `${before.yaw.toFixed(2)} -> ${after.yaw.toFixed(2)}`);
        check(`${tag}: no CSP violation or page error`, s.problems.length === 0, s.problems.join(' | '));
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
        const failed = await waitFor(async () => {
          const st = await viewerState(s.page);
          return st && /could not be loaded/i.test(st.status) ? st : null;
        });
        check(`${tag}: unreachable bytes end in the viewer failure state`, !!failed, JSON.stringify(failed));
        check(`${tag}: the failed iframe is hidden behind the Flutter failure notice`, (await s.page.locator('iframe').evaluate((el) => getComputedStyle(el).visibility)) === 'hidden');
        check(`${tag}: failure never falls back to the archive tier`, !s.seen.upload.includes('bafy-archive'), s.seen.upload.join(','));
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
        const frameBox = await s.page.locator('iframe').boundingBox();
        check(`${tag}: fullscreen viewer fills the window`, !!frameBox && frameBox.width >= layout.viewport.width - 4 && frameBox.height > layout.viewport.height * 0.6, JSON.stringify(frameBox));
        fs.writeFileSync(path.join(OUT, `${tag.replace('/', '-')}-fullscreen.png`), await s.page.screenshot());
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
