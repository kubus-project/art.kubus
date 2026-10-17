// Captures the kubus family wordmark on representative surfaces of a local
// Flutter web release build and records the accessible labels that carry it.
//
//   QA_WEB_ROOT   build/web to serve (default build/web)
//   QA_OUT        output directory (default output/playwright/family-brand)
//   QA_BROWSERS   chromium,firefox        QA_THEMES  light,dark
//   QA_LOCALES    en-US,sl-SI             QA_WIDTHS  390,1440
//
// The API is answered locally (one artwork, empty lists) and every write is
// blocked, so the run never reaches production data.
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, firefox } from 'playwright';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const webRoot = path.resolve(process.env.QA_WEB_ROOT || path.join(root, 'build/web'));
const out = path.resolve(process.env.QA_OUT || path.join(root, 'output/playwright/family-brand'));
const port = Number(process.env.QA_PORT || 8897);
const origin = `http://127.0.0.1:${port}`;
const list = (name, fallback) => (process.env[name] || fallback).split(',');
const artworkId = '11111111-1111-4111-8111-111111111111';
const artwork = {
  id: artworkId, title: 'Recorded Artwork', artist: 'Recorded Artist', description: 'Fixture artwork.',
  imageUrl: '', latitude: 46.0569, longitude: 14.5058, category: 'street art', rarity: 'common',
  createdAt: '2026-10-01T10:00:00.000Z', isPublic: true, status: 'published', metadata: {},
};

const surfaces = [
  { key: 'onboarding', path: '/onboarding', widths: [390, 1440] },
  { key: 'register', path: '/register', widths: [390, 1440] },
  { key: 'node', path: '/settings/availability-node', widths: [390, 1440] },
  { key: 'artwork', path: `/artworks/${artworkId}`, widths: [390, 1440] },
  { key: 'shell', path: '/main', widths: [1440] },
  // The desktop navigation's settings gear is an unlabeled icon button, so it is clicked by position.
  { key: 'settings', path: '/main', widths: [1440], clickAt: [158, 805] },
];

const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.webp': 'image/webp', '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf', '.woff2': 'font/woff2' };
const server = http.createServer(async (req, res) => {
  let file = path.resolve(webRoot, `.${decodeURIComponent(new URL(req.url, origin).pathname)}`);
  if (!file.startsWith(`${webRoot}${path.sep}`) && file !== webRoot) return res.writeHead(403).end();
  try { if (!(await fs.stat(file)).isFile()) file = path.join(webRoot, 'index.html'); }
  catch { file = path.join(webRoot, 'index.html'); }
  try {
    res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
    res.end(await fs.readFile(file));
  } catch { res.writeHead(404).end(); }
});
await fs.mkdir(out, { recursive: true });
await new Promise((resolve) => server.listen(port, '127.0.0.1', resolve));

const results = [];
try {
  for (const browserName of list('QA_BROWSERS', 'chromium,firefox')) {
    const browser = await (browserName === 'firefox' ? firefox : chromium).launch();
    for (const theme of list('QA_THEMES', 'light,dark'))
      for (const locale of list('QA_LOCALES', 'en-US,sl-SI'))
        for (const surface of surfaces.filter((x) => !process.env.QA_SURFACE || x.key === process.env.QA_SURFACE))
          for (const width of surface.widths.filter((w) => list('QA_WIDTHS', '390,1440').map(Number).includes(w))) {
            const name = `${surface.key}-${browserName}-${theme}-${locale.split('-')[0]}-${width}`;
            const context = await browser.newContext({
              viewport: { width, height: width < 600 ? 844 : 900 }, colorScheme: theme, locale, reducedMotion: 'reduce',
              deviceScaleFactor: 1,
            });
            const page = await context.newPage();
            const errors = [];
            page.on('pageerror', (e) => errors.push(String(e.message).slice(0, 160)));
            await context.route('**/*', async (route) => {
              const request = route.request();
              const url = new URL(request.url());
              if (url.origin === origin && !url.pathname.startsWith('/api/')) return route.continue();
              if (['blob:', 'data:'].includes(url.protocol)) return route.continue();
              if (url.pathname.startsWith('/api/')) {
                if (!['GET', 'HEAD', 'OPTIONS'].includes(request.method())) return route.fulfill({ status: 503, body: '' });
                const data = /\/artworks\//.test(url.pathname) ? artwork : [];
                return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ success: true, data }) });
              }
              return route.fulfill({ status: 404, body: '' });
            });
            const language = locale.split('-')[0];
            const target = new URL(surface.path, origin);
            target.searchParams.set('lang', language);
            let failure;
            let labels = [];
            try {
              await page.goto(target.toString(), { waitUntil: 'domcontentloaded' });
              await page.waitForSelector('flutter-view', { timeout: 60000 });
              await page.waitForTimeout(9000);
              const placeholder = page.locator('flt-semantics-placeholder');
              if (await placeholder.count()) await placeholder.evaluate((el) => el.click());
              await page.waitForTimeout(1500);
              if (surface.clickAt) {
                await page.mouse.click(surface.clickAt[0], surface.clickAt[1]);
                await page.waitForTimeout(3500);
              }
              await page.screenshot({ path: path.join(out, `${name}.png`) });
              const snapshot = await page.locator('body').ariaSnapshot();
              await fs.writeFile(path.join(out, `${name}.yml`), snapshot);
              labels = snapshot.split('\n').filter((line) => /kubus/i.test(line)).map((line) => line.trim());
              const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
              if (overflow > 0) throw new Error(`Horizontal overflow ${overflow}px`);
            } catch (error) {
              failure = String(error.message || error);
              await page.screenshot({ path: path.join(out, `${name}-failure.png`) }).catch(() => {});
            }
            results.push({ name, failure, errors, labels });
            console.log(`${name}: ${failure ? `FAIL ${failure}` : `captured (${labels.length} kubus labels)`}`);
            await context.close();
          }
    await browser.close();
  }
} finally {
  server.close();
}
await fs.writeFile(path.join(out, 'report.json'), JSON.stringify({ webRoot, results }, null, 2));
process.exitCode = results.some((r) => r.failure) ? 1 : 0;
