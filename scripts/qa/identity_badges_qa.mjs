// Avatar role badges in the community feed, measured in a real browser against a
// production Flutter web artifact with deterministic local API fixtures (no live
// API, no writes). Four posts whose authors state: artist; institution;
// artist + verified; no role. For each post at each width and theme it records
// (a) whether a role badge semantics node is present next to the author, (b) the
// spoken label of the author, and (c) a crop of the author row for review.
//
// QA_WEB_ROOT  built web root (default build/web)
// QA_MEDIA_ROOT directory with portrait.png (avatar fixture)
// QA_OUT       output directory (default output/playwright/identity-badges)
// QA_BROWSERS  chromium (default) | firefox   QA_WIDTHS 390,1440   QA_THEMES light,dark
// QA_PORT      static server port (default 8898)
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
const mediaRoot = path.resolve(process.env.QA_MEDIA_ROOT || path.join(root, 'output/qa/media-fixtures'));
const out = path.resolve(process.env.QA_OUT || path.join(root, 'output/playwright/identity-badges'));
const port = Number(process.env.QA_PORT || 8898);
const origin = `http://127.0.0.1:${port}`;
const mediaHost = 'https://qa-media.kubus.site';
const list = (name, fallback) => (process.env[name] || fallback).split(',').map(s => s.trim()).filter(Boolean);

// Expected role words per post, as the spoken badge label would contain them.
const people = [
  { name: 'Ines Alpha', id: '11111111-1111-4111-8111-111111111101', wallet: 'BadgeQaWalletAlpha1111111111111111111111111',
    roles: { artist: true }, isVerified: false, expect: ['Artist'], none: false },
  { name: 'Mara Beta', id: '11111111-1111-4111-8111-111111111102', wallet: 'BadgeQaWalletBeta11111111111111111111111111',
    roles: { institution: true }, isVerified: false, expect: ['Institution'], none: false },
  { name: 'Tomas Gamma', id: '11111111-1111-4111-8111-111111111103', wallet: 'BadgeQaWalletGamma1111111111111111111111111',
    roles: { artist: true }, isVerified: true, expect: ['Artist', 'Verified'], none: false },
  { name: 'Lena Delta', id: '11111111-1111-4111-8111-111111111104', wallet: 'BadgeQaWalletDelta11111111111111111111111111',
    roles: {}, isVerified: false, expect: [], none: true },
];
const feedPosts = () => people.map((p, i) => {
  const now = new Date(Date.now() - i * 60000).toISOString();
  return {
    id: `66666666-6666-4666-8666-66666666666${i}`,
    author: {
      id: p.id, userId: p.id, user_id: p.id, walletAddress: p.wallet,
      username: p.name.toLowerCase().replace(/\s+/g, '-'), displayName: p.name,
      avatar: `${mediaHost}/portrait.png`, roles: p.roles, isVerified: p.isVerified,
    },
    content: `identity badge QA post ${i + 1} for ${p.name}`,
    category: 'art', tags: [], mediaUrls: [], postType: 'post', timestamp: now, createdAt: now,
    stats: { likes: 0, comments: 0, shares: 0 },
  };
});

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

// Reads every visible semantics node (label or text) with its viewport rect.
const readSemantics = () => [...document.querySelectorAll('flt-semantics')].map(el => {
  const r = el.getBoundingClientRect();
  return { t: (el.getAttribute('aria-label') || el.textContent || '').trim().slice(0, 400),
    x: r.x, y: r.y, w: r.width, h: r.height };
}).filter(n => n.t && n.w > 0 && n.h > 0 && n.y >= 0 && n.y + n.h <= innerHeight);

const roleNodeRe = /^(Artist|Institution|Verified)(, (Artist|Institution|Verified))*$/;
const roleWords = ['Artist', 'Institution', 'Verified'];

const results = [];
try {
  for (const browserName of list('QA_BROWSERS', 'chromium')) {
    const browser = await playwright[browserName].launch({ headless: true });
    try {
      for (const width of list('QA_WIDTHS', '390,1440').map(Number)) {
        for (const theme of list('QA_THEMES', 'light,dark')) {
          const height = width < 768 ? 844 : 900;
          const label = `${browserName}-${width}-${theme}`;
          const context = await browser.newContext({ viewport: { width, height }, colorScheme: theme,
            reducedMotion: 'no-preference', locale: 'en-US' });
          const page = await context.newPage();
          const errors = [];
          page.on('pageerror', e => errors.push(e.message));
          const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*',
            'access-control-allow-methods': '*' };
          await context.route('**/*', async route => {
            const request = route.request(); const url = new URL(request.url());
            if (url.origin === origin || url.protocol === 'blob:' || url.protocol === 'data:') return route.continue();
            if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
            if (url.origin === mediaHost) {
              const file = path.basename(url.pathname);
              try {
                const body = await fs.readFile(path.join(mediaRoot, file));
                return route.fulfill({ status: 200, headers: cors, contentType: file.endsWith('.png') ? 'image/png' : 'video/webm', body });
              } catch { return route.fulfill({ status: 404, headers: cors, body: '' }); }
            }
            if (url.hostname === 'api.kubus.site') {
              let data = [];
              if (/\/community\/(posts|art-feed)/.test(url.pathname)) data = feedPosts();
              else if (url.pathname.endsWith('/config')) data = { communityMultiMediaEnabled: true };
              return route.fulfill({ status: 200, headers: cors, contentType: 'application/json',
                body: JSON.stringify({ success: true, data }) });
            }
            return route.fulfill({ status: 404, headers: cors, body: '' });
          });
          const record = { label, browser: browserName, width, viewportHeight: height, theme, posts: [], failure: null };
          try {
            await page.goto(`${origin}/community?lang=en`, { waitUntil: 'domcontentloaded' });
            await page.waitForSelector('flutter-view', { timeout: 90000 });
            await page.waitForFunction(() => !!document.querySelector('flt-semantics-placeholder'), null, { timeout: 60000 });
            await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
            await page.waitForFunction(names => [...document.querySelectorAll('flt-semantics')]
              .some(el => (el.getAttribute('aria-label') || el.textContent || '').includes(names[0])),
            people.map(p => p.name), { timeout: 60000 });
            await page.waitForTimeout(800);
            await page.screenshot({ path: path.join(out, `${label}-feed-top.png`) });

            // Accumulated evidence per person across scroll positions.
            const acc = Object.fromEntries(people.map(p => [p.name, { labels: new Set(), roleLabels: new Set(), cropped: false, cropPath: null }]));
            const steps = Number(process.env.QA_STEPS || 8);
            for (let step = 0; step < steps; step++) {
              const nodes = await page.evaluate(readSemantics);
              const anchors = people.map(p => {
                const hits = nodes.filter(n => n.t.includes(p.name));
                hits.forEach(h => acc[p.name].labels.add(h.t));
                if (!hits.length) return null;
                // Prefer the author row (name plus @handle), not the post body.
                const handle = '@' + p.name.toLowerCase().replace(/\s+/g, '-');
                const rows = hits.filter(h => h.t.includes(handle));
                const pool = rows.length ? rows : hits;
                return pool.reduce((a, b) => (b.h < a.h ? b : a));
              });
              // The badge is merged into the author row's label: role words are
              // their own lines of that label. A standalone role node also counts.
              // Only compact name nodes count, so whole-feed blobs do not.
              people.forEach((p, i) => {
                const a = anchors[i];
                if (!a || a.h > 200) return;
                const row = nodes.filter(n => n.t.includes(p.name) && n.h <= 200);
                for (const n of row) {
                  for (const line of n.t.split(String.fromCharCode(10)).map(l => l.trim())) {
                    if (roleNodeRe.test(line)) acc[p.name].roleLabels.add(line);
                  }
                }
              });
              for (const rn of nodes.filter(n => roleNodeRe.test(n.t))) {
                const rc = rn.y + rn.h / 2;
                let best = null;
                people.forEach((p, i) => {
                  const a = anchors[i];
                  if (!a) return;
                  const d = Math.abs(a.y + a.h / 2 - rc);
                  if (d < 120 && (!best || d < best.d)) best = { i, d };
                });
                if (best) acc[people[best.i].name].roleLabels.add(rn.t);
              }
              for (let i = 0; i < people.length; i++) {
                const a = anchors[i]; const p = people[i];
                if (!a || acc[p.name].cropped || a.h > 200) continue;
                acc[p.name].cropped = true;
                const clip = { x: Math.max(0, a.x - 72), y: Math.max(0, a.y - 40),
                  width: Math.min(width - Math.max(0, a.x - 72), 320), height: Math.min(a.h + 80, height) };
                const cropPath = path.join(out, `${label}-author-${i + 1}.png`);
                await page.screenshot({ path: cropPath, clip });
                acc[p.name].cropPath = path.basename(cropPath);
              }
              await page.mouse.move(width / 2, 500);
              await page.mouse.wheel(0, 350);
              await page.waitForTimeout(700);
            }
            await page.screenshot({ path: path.join(out, `${label}-feed-end.png`) });

            record.posts = people.map((p, i) => {
              const a = acc[p.name];
              const roleSet = new Set([...a.roleLabels].flatMap(l => l.split(', ')));
              const roleLabelText = [...a.roleLabels].join(' | ') || null;
              const badgeVisible = a.roleLabels.size > 0;
              const expectedOk = p.none
                ? !badgeVisible
                : badgeVisible && p.expect.every(w => roleSet.has(w)) && roleSet.size === p.expect.length;
              const labelIncludesRole = [...a.labels].some(l => roleWords.some(w => p.expect.includes(w) && l.includes(w)));
              return {
                post: i + 1, name: p.name,
                roleStated: p.none ? 'none' : [...(p.roles.artist ? ['artist'] : []), ...(p.roles.institution ? ['institution'] : []), ...(p.isVerified ? ['verified'] : [])].join('+'),
                expectedBadge: p.expect.join(', ') || null,
                badgeVisible, badgeLabel: roleLabelText,
                nameLabels: [...a.labels].filter(l => l.length <= 200).slice(0, 4),
                labelIncludesRole: p.none ? null : labelIncludesRole,
                crop: a.cropPath,
                pass: expectedOk && (p.none || labelIncludesRole || badgeVisible),
              };
            });
            record.errors = errors;
          } catch (e) {
            record.failure = e.message;
            await page.screenshot({ path: path.join(out, `${label}-failure.png`) }).catch(() => {});
          }
          results.push(record);
          const summary = record.failure ? `FAILED: ${record.failure.slice(0, 160)}`
            : record.posts.map(p => `${p.post}:${p.badgeVisible ? 'badge' : 'none'}${p.pass ? '' : '(FAIL)'}`).join(' ');
          console.log(`${label}: ${summary}`);
          await context.close();
          await fs.writeFile(path.join(out, 'report.json'), JSON.stringify({ webRoot, results }, null, 2));
        }
      }
    } finally { await browser.close(); }
  }
} finally { await new Promise(resolve => server.close(resolve)); }
