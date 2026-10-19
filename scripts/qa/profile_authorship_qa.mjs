// Profile authorship sections in a real browser against a production Flutter web
// artifact with deterministic local API fixtures (no live API, no writes). A
// visitor opens an artist's public profile whose wallet manages three authored
// works and three documented public-art records. The run records which titles
// appear between the artworks heading and the "Public art added" heading, and
// which appear after it, and fails on any cross-contamination.
//
// QA_BACKEND   scoped (default: backend honours ?relationship) | legacy (old
//              backend ignores it: one mixed list, no "Public art added")
// QA_WEB_ROOT  built web root (default build/web)
// QA_OUT       output directory (default output/playwright/profile-authorship)
// QA_BROWSERS  chromium (default) | firefox   QA_WIDTHS 390,1440   QA_THEMES light,dark
// QA_PORT      static server port (default 8899)   QA_HEIGHT viewport height (default 4000)
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const playwright = (() => {
  for (const id of [process.env.PLAYWRIGHT_PATH, 'playwright'].filter(Boolean)) {
    try { return require(id); } catch { /* try next */ }
  }
  throw new Error('playwright not found; set PLAYWRIGHT_PATH');
})();

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const webRoot = path.resolve(process.env.QA_WEB_ROOT || path.join(root, 'build/web'));
const out = path.resolve(process.env.QA_OUT || path.join(root, 'output/playwright/profile-authorship'));
const port = Number(process.env.QA_PORT || 8899);
const origin = `http://127.0.0.1:${port}`;
const backendMode = process.env.QA_BACKEND || 'scoped';
const list = (name, fallback) => (process.env[name] || fallback).split(',').map(s => s.trim()).filter(Boolean);

const wallet = 'AuthorshipQaWallet11111111111111111111111111';
const userId = '22222222-2222-4222-8222-222222222201';
const profile = {
  id: userId, userId, walletAddress: wallet, wallet_address: wallet,
  username: 'ana-qa', displayName: 'Ana Authorship', display_name: 'Ana Authorship',
  bio: 'Painter. Also documents murals around the city.', avatar: null,
  isArtist: true, is_artist: true, roles: { artist: true }, isVerified: false,
  preferences: {}, createdAt: '2025-01-01T00:00:00.000Z',
};
const artwork = (n, title, relationship, artistName, category) => ({
  id: `33333333-3333-4333-8333-3333333333${String(n).padStart(2, '0')}`,
  title, description: '', imageUrl: null, category, tags: [],
  artistName, relationship,
  attribution: relationship === 'authored' ? { verification: 'self_declared', source: 'legacy_creator_record' } : null,
  isForSale: false, stats: { viewsCount: 0, likesCount: 0, commentsCount: 0, sharesCount: 0 },
  createdAt: `2026-10-0${n}T10:00:00.000Z`, updatedAt: `2026-10-0${n}T10:00:00.000Z`,
});
const authored = [
  artwork(1, 'Quiet Harbour Study', 'authored', 'Ana Authorship', 'Painting'),
  artwork(2, 'Linden Grove Triptych', 'authored', 'Ana Authorship', 'Painting'),
  artwork(3, 'Salt Pan Morning', 'authored', 'Ana Authorship', 'Painting'),
];
const documented = [
  artwork(4, 'Tram Depot Mural', 'documented', 'Mural Hand', 'Street art'),
  artwork(5, 'River Wall Mosaic', 'documented', 'Studio Tessera', 'Mosaic'),
  artwork(6, 'Bridge Underpass Piece', 'documented', 'Unknown artist', 'Street art'),
];
const artworksResponse = (relationship) => {
  if (backendMode === 'legacy' || !relationship) {
    const data = [...authored, ...documented].map(({ relationship: _r, attribution: _a, artistName: _n, ...rest }) => rest);
    return { success: true, count: data.length, data, pagination: { limit: 6, offset: 0, total: data.length } };
  }
  const data = relationship === 'authored' ? authored : relationship === 'documented' ? documented : [...authored, ...documented];
  return { success: true, count: data.length, data, relationship, pagination: { limit: 6, offset: 0, total: data.length } };
};
const counters = backendMode === 'legacy'
  ? { artworks: 6, followers: 4, following: 2, posts: 0 }
  : { artworks: 6, authoredArtworks: 3, documentedArtworks: 3, followers: 4, following: 2, posts: 0 };

const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.webp': 'image/webp', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.woff2': 'font/woff2' };
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
await new Promise(resolve => server.listen(port, '127.0.0.1', resolve));

const readSemantics = () => [...document.querySelectorAll('flt-semantics')].map(el => {
  const r = el.getBoundingClientRect();
  return { t: (el.getAttribute('aria-label') || el.textContent || '').trim().slice(0, 300), y: r.y, h: r.height, w: r.width };
}).filter(n => n.t && n.w > 0 && n.h > 0);

const artworksHeadings = ['Artworks', 'Portfolio', 'Artist portfolio'];
const documentedHeading = 'Public art added';
const results = [];
try {
  for (const browserName of list('QA_BROWSERS', 'chromium')) {
    const browser = await playwright[browserName].launch({ headless: true });
    try {
      for (const width of list('QA_WIDTHS', '390,1440').map(Number)) {
        for (const theme of list('QA_THEMES', 'light,dark')) {
          // One tall viewport renders the whole profile at once, so every node's y
          // comes from the same layout and section order is unambiguous.
          const height = Number(process.env.QA_HEIGHT || 4000);
          const label = `${backendMode}-${browserName}-${width}-${theme}`;
          const context = await browser.newContext({ viewport: { width, height }, colorScheme: theme, locale: 'en-US' });
          const page = await context.newPage();
          const errors = []; const requests = [];
          page.on('pageerror', e => errors.push(e.message));
          const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': '*' };
          await context.route('**/*', async route => {
            const request = route.request(); const url = new URL(request.url());
            if (url.origin === origin || url.protocol === 'blob:' || url.protocol === 'data:') return route.continue();
            if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
            if (url.hostname === 'api.kubus.site') {
              requests.push(`${request.method()} ${url.pathname}${url.search}`);
              const json = (body) => route.fulfill({ status: 200, headers: cors, contentType: 'application/json', body: JSON.stringify(body) });
              if (url.pathname.endsWith(`/profiles/${wallet}/artworks`)) return json(artworksResponse(url.searchParams.get('relationship')));
              if (url.pathname.endsWith(`/profiles/${wallet}/stats`)) return json({ success: true, data: { walletAddress: wallet, artworksCreated: 6, authoredArtworksCount: 3, documentedArtworksCount: 3 } });
              if (url.pathname.includes('/stats/')) return json({ success: true, data: { counters } });
              if (url.pathname.endsWith(`/profiles/${wallet}`) || url.pathname.endsWith(`/profiles/${userId}`)) return json({ success: true, data: profile });
              if (url.pathname.endsWith('/config')) return json({ success: true, data: {} });
              return json({ success: true, data: [] });
            }
            return route.fulfill({ status: 404, headers: cors, body: '' });
          });
          const record = { label, backendMode, browser: browserName, width, theme, failure: null };
          try {
            await page.goto(`${origin}/profile/${wallet}?lang=en`, { waitUntil: 'domcontentloaded' });
            await page.waitForSelector('flutter-view', { timeout: 90000 });
            await page.waitForFunction(() => !!document.querySelector('flt-semantics-placeholder'), null, { timeout: 60000 });
            await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
            await page.waitForFunction(() => [...document.querySelectorAll('flt-semantics')]
              .some(el => (el.getAttribute('aria-label') || el.textContent || '').includes('Quiet Harbour Study')), null, { timeout: 60000 });
            await page.waitForTimeout(800);
            const nodes = await page.evaluate(readSemantics);
            await page.screenshot({ path: path.join(out, `${label}.png`) });
            const firstY = (pred) => nodes.filter(pred).map(n => n.y).sort((a, b) => a - b)[0];
            const artworksY = firstY(n => artworksHeadings.includes(n.t));
            const documentedY = firstY(n => n.t === documentedHeading || n.t.startsWith(`${documentedHeading}\n`));
            const titleY = (title) => firstY(n => n.t.includes(title) && n.h < 400);
            const place = (title) => {
              const y = titleY(title);
              if (y === undefined) return 'absent';
              if (documentedY !== undefined && y > documentedY) return 'public-art-added';
              if (artworksY !== undefined && y > artworksY) return 'artworks';
              return 'elsewhere';
            };
            record.headings = { artworksY, documentedY };
            record.authored = Object.fromEntries(authored.map(a => [a.title, place(a.title)]));
            record.documented = Object.fromEntries(documented.map(a => [a.title, place(a.title)]));
            record.credits = documented.map(a => a.artistName).filter(name => nodes.some(n => n.t.includes(name)));
            record.artworkRequests = requests.filter(r => r.includes('/artworks'));
            record.errors = errors;
            if (backendMode === 'scoped') {
              record.pass = documentedY !== undefined
                && Object.values(record.authored).every(p => p === 'artworks')
                && Object.values(record.documented).every(p => p === 'public-art-added');
            } else {
              // Old backend: one mixed list in the artworks section, no second section.
              record.pass = documentedY === undefined;
            }
          } catch (e) {
            record.failure = e.message;
            record.pass = false;
            await page.screenshot({ path: path.join(out, `${label}-failure.png`) }).catch(() => {});
          }
          results.push(record);
          console.log(`${label}: ${record.failure ? `FAILED ${record.failure.slice(0, 160)}` : `${record.pass ? 'PASS' : 'FAIL'} authored=${JSON.stringify(record.authored)} documented=${JSON.stringify(record.documented)}`}`);
          await context.close();
          await fs.writeFile(path.join(out, `report-${backendMode}.json`), JSON.stringify({ webRoot, results }, null, 2));
        }
      }
    } finally { await browser.close(); }
  }
} finally {
  server.close();
}
process.exit(results.every(r => r.pass) ? 0 : 1);
