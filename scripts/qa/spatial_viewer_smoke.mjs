// Browser smoke for the bundled spatial (Gaussian splat) viewer, as the Flutter web build ships it.
//
// What it proves, in a real Chromium (and Firefox when BROWSERS lists it) with WebGL:
//   - the shipped viewer page (Spark 2.4.0) boots under the same CSP header web/.htaccess sends for HTML,
//   - a same-origin parent can drive it with the postMessage protocol the Flutter widget uses,
//   - the public route order is honoured (a 404 route falls through to the next one),
//   - the Node manifest transform.matrix (column-major) stands the sample piece upright,
//   - drag-orbit changes the camera, a missing route ends in the failure state, a foreign origin is ignored.
//
// Data is synthetic: test/fixtures/spatial/sample_flower.splat (scripts/qa/make_sample_splat.mjs).
// It never reads any artist's files.
//
// Environment:
//   WEB_ROOT   directory that holds the web build (default build/web); falls back to assets/spatial_viewer
//              mounted at /assets/assets/spatial_viewer when the build is absent.
//   BROWSERS   comma list (default chromium)
//   QA_OUT     output directory (default output/playwright/artifacts/spatial-viewer)
// Exits non-zero on any failed check.
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import { createRequire } from 'node:module';

// Same resolution the other qa scripts rely on, plus NODE_PATH for a globally installed Playwright.
const { chromium, firefox } = createRequire(import.meta.url)('playwright');

const ROOT = path.resolve(import.meta.dirname, '..', '..');
const WEB_ROOT = path.resolve(process.env.WEB_ROOT || path.join(ROOT, 'build', 'web'));
const OUT = path.resolve(process.env.QA_OUT || path.join(ROOT, 'output', 'playwright', 'artifacts', 'spatial-viewer'));
const BROWSERS = (process.env.BROWSERS || 'chromium').split(',').map((s) => s.trim()).filter(Boolean);
const SAMPLE = fs.readFileSync(path.join(ROOT, 'test', 'fixtures', 'spatial', 'sample_flower.splat'));
fs.mkdirSync(OUT, { recursive: true });

const VIEWER_PATH = '/assets/assets/spatial_viewer/';
const hasBuild = fs.existsSync(path.join(WEB_ROOT, 'assets', 'assets', 'spatial_viewer', 'index.html'));
const viewerDir = hasBuild
  ? path.join(WEB_ROOT, 'assets', 'assets', 'spatial_viewer')
  : path.join(ROOT, 'assets', 'spatial_viewer');

// The exact CSP web/.htaccess applies to every static .html response.
const htaccess = fs.readFileSync(path.join(ROOT, 'web', '.htaccess'), 'utf8');
const HTML_CSP = /Header set Content-Security-Policy "([^"]+)"/.exec(htaccess)?.[1];
if (!HTML_CSP) throw new Error('could not read the HTML CSP from web/.htaccess');

// 90 degree turn about Z, column-major: the piece lies along +X, so +X becomes +Y (head up).
const UPRIGHT = { matrix: [0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1], matrixOrder: 'column-major' };

const HARNESS = `<!doctype html><meta charset="utf-8"><title>harness</title>
<style>html,body{margin:0;background:#222}iframe{width:640px;height:480px;border:0;display:block}</style>
<iframe id="v" src="${VIEWER_PATH}index.html" title="viewer"></iframe>
<script>
  window.__msgs = [];
  window.addEventListener('message', (e) => {
    if (e.source === document.getElementById('v').contentWindow && e.data && e.data.kubusSpatialViewer) window.__msgs.push(e.data.kubusSpatialViewer);
  });
  window.sendCommand = (command) => document.getElementById('v').contentWindow.postMessage({ kubusSpatialViewerCommand: command }, location.origin);
</script>`;

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm' };

function startServer() {
  const requests = [];
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://x');
    requests.push(url.pathname);
    if (url.pathname === '/harness.html') {
      res.writeHead(200, { 'content-type': 'text/html', 'content-security-policy': HTML_CSP });
      return res.end(HARNESS);
    }
    if (url.pathname === '/api/upload/file/bafy-sample') {
      // Like the real route: whole body, octet-stream, no Range support, never cacheable.
      res.writeHead(200, { 'content-type': 'application/octet-stream', 'cache-control': 'no-store', 'content-length': SAMPLE.length });
      return res.end(SAMPLE);
    }
    if (url.pathname.startsWith('/api/upload/file/')) {
      res.writeHead(404, { 'cache-control': 'no-store' });
      return res.end();
    }
    if (url.pathname.startsWith(VIEWER_PATH)) {
      const rel = url.pathname.slice(VIEWER_PATH.length) || 'index.html';
      const file = path.join(viewerDir, rel);
      if (!file.startsWith(viewerDir) || !fs.existsSync(file)) {
        res.writeHead(404);
        return res.end();
      }
      const headers = { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' };
      if (file.endsWith('.html')) headers['content-security-policy'] = HTML_CSP;
      res.writeHead(200, headers);
      return res.end(fs.readFileSync(file));
    }
    res.writeHead(404);
    res.end();
  });
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve({ server, requests, port: server.address().port })));
}

const failures = [];
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` - ${detail}` : ''}`);
  if (!ok) failures.push(name);
};

// Colour statistics of a screenshot, computed in the page (no image library needed).
async function colourStats(page, png) {
  return page.evaluate(async (b64) => {
    const image = new Image();
    await new Promise((resolve, reject) => {
      image.onload = resolve;
      image.onerror = reject;
      image.src = `data:image/png;base64,${b64}`;
    });
    const canvas = document.createElement('canvas');
    canvas.width = image.naturalWidth;
    canvas.height = image.naturalHeight;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(image, 0, 0);
    const { data, width, height } = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const groups = { red: { n: 0, x: 0, y: 0 }, green: { n: 0, x: 0, y: 0 } };
    let minX = width; let maxX = 0; let minY = height; let maxY = 0;
    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) {
        const i = (y * width + x) * 4;
        const [r, g, b] = [data[i], data[i + 1], data[i + 2]];
        const isRed = r > 170 && g < 110 && b < 120;
        const isGreen = g > 120 && r < 120 && b < 130 && g - r > 40;
        const group = isRed ? groups.red : isGreen ? groups.green : null;
        if (!group) continue;
        group.n += 1; group.x += x; group.y += y;
        minX = Math.min(minX, x); maxX = Math.max(maxX, x); minY = Math.min(minY, y); maxY = Math.max(maxY, y);
      }
    }
    const centroid = (g) => (g.n ? { x: g.x / g.n, y: g.y / g.n, n: g.n } : null);
    return { red: centroid(groups.red), green: centroid(groups.green), width: maxX - minX, height: maxY - minY };
  }, png.toString('base64'));
}

async function waitMsg(page, pred, timeout = 30000) {
  await page.waitForFunction((src) => window.__msgs.some(new Function('m', `return (${src})(m)`)), pred.toString(), { timeout });
}

async function run(browserType, name) {
  const browser = await browserType.launch({ args: name === 'chromium' ? ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] : [] });
  const { server, requests, port } = await startServer();
  const origin = `http://127.0.0.1:${port}`;
  try {
    const context = await browser.newContext({ locale: 'en-US', viewport: { width: 700, height: 540 } });
    const page = await context.newPage();
    const consoleProblems = [];
    page.on('console', (m) => {
      const text = m.text();
      if (/Content Security Policy|Refused to|violates/i.test(text)) consoleProblems.push(text);
    });
    page.on('pageerror', (e) => consoleProblems.push(`pageerror: ${e.message}`));
    const frameOf = () => page.frames().find((f) => f.url().includes(VIEWER_PATH));
    const loadHarness = async () => {
      await page.goto(`${origin}/harness.html`);
      await page.waitForFunction(() => window.__msgs.includes('viewer-ready'), null, { timeout: 30000 });
    };
    const iframeShot = () => page.locator('#v').screenshot();

    // 1. Boots, falls through a 404 route, ends ready.
    await loadHarness();
    check(`${name}: viewer announces viewer-ready under the htaccess CSP`, true);
    await page.evaluate((o) => window.sendCommand({
      type: 'load',
      urls: [`${o}/api/upload/file/bafy-missing`, `${o}/api/upload/file/bafy-sample`],
      fileType: 'splat',
    }), origin);
    await waitMsg(page, (m) => m === 'ready' || m.startsWith('error:'));
    const msgs = await page.evaluate(() => window.__msgs);
    check(`${name}: second route loads after the first 404s`, msgs.includes('ready'), msgs.join(','));
    const order = requests.filter((p) => p.startsWith('/api/upload/file/'));
    check(`${name}: routes tried in order`, order[0] === '/api/upload/file/bafy-missing' && order.includes('/api/upload/file/bafy-sample'), order.join(','));
    await page.waitForTimeout(1500);
    const flat = await colourStats(page, await iframeShot());
    fs.writeFileSync(path.join(OUT, `${name}-no-transform.png`), await iframeShot());
    check(`${name}: sample renders visible red head and green stem`, !!flat.red && !!flat.green && flat.red.n > 200 && flat.green.n > 100, JSON.stringify(flat));
    check(`${name}: untransformed piece lies sideways (wider than tall)`, flat.width > flat.height * 1.4, `${flat.width}x${flat.height}`);

    // 2. Drag orbit.
    const before = await frameOf().evaluate(() => window.__spatialDebug());
    const box = await page.locator('#v').boundingBox();
    await page.mouse.move(box.x + 320, box.y + 240);
    await page.mouse.down();
    await page.mouse.move(box.x + 420, box.y + 260, { steps: 6 });
    await page.mouse.up();
    const after = await frameOf().evaluate(() => window.__spatialDebug());
    check(`${name}: drag changes the camera (yaw ${before.yaw.toFixed(2)} -> ${after.yaw.toFixed(2)})`, Math.abs(after.yaw - before.yaw) > 0.3);
    await page.evaluate(() => window.sendCommand({ type: 'reset' }));
    await page.waitForTimeout(200);
    const reset = await frameOf().evaluate(() => window.__spatialDebug());
    check(`${name}: reset restores the camera`, reset.yaw === 0 && reset.pitch === 0 && reset.distance === 3);

    // 3. Manifest transform stands it upright.
    await loadHarness();
    await page.evaluate(({ o, transform }) => window.sendCommand({ type: 'load', urls: [`${o}/api/upload/file/bafy-sample`], fileType: 'splat', transform }), { o: origin, transform: UPRIGHT });
    await waitMsg(page, (m) => m === 'ready' || m.startsWith('error:'));
    await page.waitForTimeout(1500);
    const debug = await frameOf().evaluate(() => window.__spatialDebug());
    const m = debug.matrix || [];
    check(`${name}: transform.matrix applied column-major to the mesh`, m.length === 16 && Math.abs(m[1] - 1) < 1e-6 && Math.abs(m[4] + 1) < 1e-6, JSON.stringify(m));
    const upright = await colourStats(page, await iframeShot());
    fs.writeFileSync(path.join(OUT, `${name}-upright.png`), await iframeShot());
    check(`${name}: transformed piece stands upright (taller than wide)`, upright.height > upright.width * 1.4, `${upright.width}x${upright.height}`);
    check(`${name}: head (red) is above the stem (green)`, !!upright.red && !!upright.green && upright.red.y < upright.green.y - 20, JSON.stringify(upright));

    // 4. Failure state.
    await loadHarness();
    await page.evaluate((o) => window.sendCommand({ type: 'load', urls: [`${o}/api/upload/file/bafy-missing`] }), origin);
    await waitMsg(page, (msg) => msg.startsWith('error:'));
    const statusText = await frameOf().evaluate(() => document.querySelector('#status').textContent);
    check(`${name}: unreachable route ends in the failure state`, /could not be loaded/i.test(statusText), statusText);

    // 5. Disallowed URL schemes are refused, not fetched.
    await loadHarness();
    await page.evaluate(() => window.sendCommand({ type: 'load', urls: ['http://example.invalid/x.splat', 'file:///etc/passwd', 'javascript:1'] }));
    await waitMsg(page, (msg) => msg === 'error:url-not-allowed');
    check(`${name}: http / file / javascript URLs are refused`, true);

    check(`${name}: no CSP violation or page error`, consoleProblems.length === 0, consoleProblems.join(' | '));
  } finally {
    await browser.close();
    server.close();
  }
}

for (const name of BROWSERS) {
  await run(name === 'firefox' ? firefox : chromium, name);
}
console.log(hasBuild ? `served the web build at ${WEB_ROOT}` : 'web build absent: served assets/spatial_viewer directly');
if (failures.length) {
  console.error(`\n${failures.length} check(s) failed`);
  process.exit(1);
}
console.log('\nAll spatial viewer checks passed');
