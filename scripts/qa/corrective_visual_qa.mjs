// Production Flutter artifact, deterministic local API/media fixtures. No live
// credentials or writes. Generated clips are QA evidence, never product data.
// QA_WEB_ROOT, QA_MEDIA_ROOT, QA_OUT, QA_BROWSERS, QA_WIDTHS, QA_THEMES,
// QA_LOCALES, QA_MOTION, QA_PATH, QA_OWNER configure the bounded matrix.
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium, firefox } from 'playwright';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const webRoot = path.resolve(process.env.QA_WEB_ROOT || path.join(root, 'build/web'));
const mediaRoot = path.resolve(process.env.QA_MEDIA_ROOT || path.join(root, 'output/qa/media-fixtures'));
const out = path.resolve(process.env.QA_OUT || path.join(root, 'output/playwright/corrective'));
const port = Number(process.env.QA_PORT || 8893);
const origin = `http://127.0.0.1:${port}`;
const list = (name, fallback) => (process.env[name] || fallback).split(',');
const ownerId = '22222222-2222-4222-8222-222222222222';
const visitorId = '33333333-3333-4333-8333-333333333333';
const artworkId = '11111111-1111-4111-8111-111111111111';
const wallet = 'ArtistWallet111111111111111111111111111111111';
const mediaHost = 'https://qa-media.kubus.site';
const profile = (id) => ({
  id, userId: id, user_id: id, walletAddress: id === ownerId ? wallet : id,
  username: id === ownerId ? 'visual-qa-owner' : 'visual-qa-visitor',
  displayName: id === ownerId ? 'Alexandra Katarina Longname' : 'Visitor Artist',
  bio: 'Browser fixture for the 0.8.3 visual regression pass.',
  avatar: `${origin}/images/social-preview-default.webp`,
  coverImage: `${origin}/images/social-preview-default.webp`,
  isArtist: true, isInstitution: true, isVerified: true,
  preferences: { privacy: 'public', language: 'en', persona: 'creator' },
  createdAt: '2026-01-10T10:00:00Z', updatedAt: '2026-10-01T10:00:00Z',
});
const shapes = { portrait: 9 / 16, landscape: 16 / 9, square: 1, ultrawide: 21 / 9 };
const posts = Object.entries(shapes).filter(([shape]) => !process.env.QA_SHAPE || process.env.QA_SHAPE === shape).map(([shape, aspect], i) => ({
  id: `66666666-6666-4666-8666-66666666666${i}`,
  author: profile(i === 0 ? ownerId : visitorId),
  content: `${shape} video — #Art #Ljubljana`, category: 'art', tags: ['Art', 'Ljubljana'],
  mediaUrls: [`${mediaHost}/${shape}.webm#kubus-media=video&kubus-aspect=${aspect}&kubus-poster=${encodeURIComponent(`${mediaHost}/${shape}.png`)}`],
  timestamp: new Date(Date.now() - i * 60000).toISOString(),
  createdAt: new Date(Date.now() - i * 60000).toISOString(),
  artwork: { id: artworkId, title: 'Recorded Artwork', artist: 'Recorded Artist' },
  subjectType: 'artwork', subjectId: artworkId,
  location: { name: 'Ljubljana', lat: 46.0569, lng: 14.5058 },
  stats: { likes: 2, comments: 0, shares: 0 },
}));

const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.webp': 'image/webp', '.svg': 'image/svg+xml', '.ttf': 'font/ttf', '.woff2': 'font/woff2' };
const server = http.createServer(async (req, res) => {
  let file = path.resolve(webRoot, `.${decodeURIComponent(new URL(req.url, origin).pathname)}`);
  if (!file.startsWith(`${webRoot}${path.sep}`) && file !== webRoot) return res.writeHead(403).end();
  try { if (!(await fs.stat(file)).isFile()) file = path.join(webRoot, 'index.html'); }
  catch { file = path.join(webRoot, 'index.html'); }
  try { res.writeHead(200, { 'content-type': types[path.extname(file)] || 'application/octet-stream',
    'cache-control': 'no-store' }); res.end(await fs.readFile(file)); }
  catch { res.writeHead(404).end(); }
});
await fs.mkdir(out, { recursive: true });
await new Promise(resolve => server.listen(port, '127.0.0.1', resolve));
const results = [];
try {
  for (const browserName of list('QA_BROWSERS', 'chromium,firefox')) {
    const browser = await ({ chromium, firefox }[browserName]).launch({ headless: true });
    try {
      for (const theme of list('QA_THEMES', 'light,dark'))
        for (const locale of list('QA_LOCALES', 'en-US,sl-SI'))
          for (const motion of list('QA_MOTION', 'reduce,no-preference'))
            for (const width of list('QA_WIDTHS', '320,360,390,430,768,1440,1920').map(Number)) {
              const name = `${browserName}-${theme}-${locale}-${motion}-${width}`;
              const context = await browser.newContext({ viewport: { width, height: width < 768 ? 844 : 900 },
                colorScheme: theme, locale, reducedMotion: motion,
                geolocation: { latitude: 46.0569, longitude: 14.5058 }, permissions: ['geolocation'] });
              const page = await context.newPage();
              const requests = []; const errors = []; const writesBlocked = [];
              page.on('pageerror', e => errors.push(e.message));
              await context.route('**/*', async route => {
                const request = route.request(); const url = new URL(request.url());
                if (url.origin === origin || url.protocol === 'blob:' || url.protocol === 'data:') return route.continue();
                if (url.origin === mediaHost) {
                  const filename = path.basename(url.pathname);
                  try { return route.fulfill({ status: 200, contentType: filename.endsWith('.png') ? 'image/png' : 'video/webm', body: await fs.readFile(path.join(mediaRoot, filename)) }); }
                  catch { return route.fulfill({ status: 404, body: '' }); }
                }
                if (url.pathname.startsWith('/api/')) {
                  requests.push({ method: request.method(), path: url.pathname, search: url.search });
                  if (!['GET', 'HEAD', 'OPTIONS'].includes(request.method())) writesBlocked.push(url.pathname);
                  let data = [];
                  if (/\/profiles\//.test(url.pathname)) data = profile(url.pathname.includes(visitorId) ? visitorId : ownerId);
                  else if (/\/auth\/.*(me|session)/.test(url.pathname)) data = { user: profile(ownerId), profile: profile(ownerId) };
                  else if (/\/community\/(posts|art-feed)/.test(url.pathname)) data = posts;
                  else if (/\/artworks\//.test(url.pathname)) data = { id: artworkId, title: 'Recorded Artwork', artist: 'Recorded Artist',
                    description: 'QA fixture: artist differs from uploader.', artistName: 'Recorded Artist',
                    metadata: { artistUserId: ownerId }, imageUrl: `${origin}/images/social-preview-default.webp`,
                    latitude: 46.0569, longitude: 14.5058, createdAt: '2026-01-01T00:00:00Z' };
                  else if (url.pathname.endsWith('/config')) data = { communityMultiMediaEnabled: true };
                  return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ success: true, data }) });
                }
                // This matrix owns its fixture network; unrecognized external
                // dependencies fail closed rather than contacting production.
                return route.fulfill({ status: 404, body: '' });
              });
              if (process.env.QA_OWNER === 'true') await page.addInitScript(({ ownerId, wallet }) => {
                const encode = x => btoa(JSON.stringify(x)).replaceAll('=', '').replaceAll('+', '-').replaceAll('/', '_');
                const token = `${encode({ alg: 'none', typ: 'JWT' })}.${encode({ sub: ownerId, userId: ownerId, walletAddress: wallet, exp: Math.floor(Date.now()/1000)+3600 })}.fixture`;
                localStorage.setItem('flutter.jwt_token', JSON.stringify(token));
                localStorage.setItem('flutter.wallet_address', JSON.stringify(wallet));
              }, { ownerId, wallet });
              let failure;
              try {
                await page.goto(`${origin}${process.env.QA_PATH || '/community'}`, { waitUntil: 'domcontentloaded' });
                await page.waitForSelector('flutter-view', { timeout: 60000 });
                await page.waitForTimeout(10000);
                const placeholder = page.locator('flt-semantics-placeholder');
                if (await placeholder.count()) await placeholder.evaluate(el => el.click());
                await page.waitForTimeout(1500);
                await page.screenshot({ path: path.join(out, `${name}-initial.png`) });
                const initial = await page.locator('body').ariaSnapshot();
                await fs.writeFile(path.join(out, `${name}-initial.yml`), initial);
                const stageBefore = await page.getByRole('group', { name: 'Media 1 of 1', exact: true }).first().boundingBox().catch(() => null);
                // Caller supplies a semantic label for bounded navigation QA.
                if (process.env.QA_CLICK) {
                  const target = page.getByRole(process.env.QA_CLICK_ROLE || 'button', { name: new RegExp(process.env.QA_CLICK) }).first();
                  let box = await target.boundingBox();
                  if (!box) throw new Error(`Missing action: ${process.env.QA_CLICK}`);
                  for (let attempt = 0; attempt < 8 && (box.y + box.height / 2 > (width < 768 ? 720 : 780) || box.y < 80); attempt++) {
                    await page.mouse.move(width / 2, 500);
                    await page.mouse.wheel(0, box.y < 80 ? -350 : 350);
                    await page.waitForTimeout(500);
                    box = await target.boundingBox();
                    if (!box) throw new Error('Action disappeared while scrolling');
                  }
                  await page.mouse.click(box.x + box.width/2, box.y + box.height/2);
                  await page.waitForTimeout(4000);
                  await page.screenshot({ path: path.join(out, `${name}-action.png`) });
                  await fs.writeFile(path.join(out, `${name}-action.yml`), await page.locator('body').ariaSnapshot());
                }
                const playback = await page.evaluate(() => {
                  const deep = root => [...root.querySelectorAll('*')].flatMap(el => [el, ...(el.shadowRoot ? deep(el.shadowRoot) : [])]);
                  return deep(document).filter(v => v.tagName === 'VIDEO').map(v => ({
                  width: v.videoWidth, height: v.videoHeight, time: v.currentTime, paused: v.paused, muted: v.muted,
                  readyState: v.readyState, rect: v.getBoundingClientRect().toJSON() })); });
                await page.waitForTimeout(2000);
                const afterPlayback = await page.evaluate(() => {
                  const deep = root => [...root.querySelectorAll('*')].flatMap(el => [el, ...(el.shadowRoot ? deep(el.shadowRoot) : [])]);
                  return deep(document).filter(v => v.tagName === 'VIDEO').map(v => ({ time: v.currentTime, paused: v.paused })); });
                const stageAfter = await page.getByRole('group', { name: 'Media 1 of 1', exact: true }).first().boundingBox().catch(() => null);
                const captures = [];
                for (const captureWidth of list('QA_CAPTURE_WIDTHS', String(width)).map(Number)) {
                  await page.setViewportSize({ width: captureWidth, height: captureWidth < 768 ? 844 : 900 });
                  await page.waitForTimeout(700);
                  await page.screenshot({ path: path.join(out, `${name}-width-${captureWidth}.png`) });
                  captures.push({ width: captureWidth, overflow: await page.evaluate(() => document.documentElement.scrollWidth > innerWidth) });
                }
                let fullscreen;
                if (process.env.QA_FULLSCREEN === 'true') {
                  await page.setViewportSize({ width, height: width < 768 ? 844 : 900 });
                  const button = page.getByRole('button', { name: 'Full screen', exact: true }).first();
                  const box = await button.boundingBox();
                  if (!box) throw new Error('Fullscreen control missing');
                  await page.mouse.click(box.x+box.width/2, box.y+box.height/2);
                  await page.waitForTimeout(1000);
                  fullscreen = await page.locator('body').ariaSnapshot();
                  await page.screenshot({ path: path.join(out, `${name}-fullscreen.png`) });
                  await page.keyboard.press('Escape');
                  await page.waitForTimeout(500);
                }
                results.push({ name, errors, writesBlocked, requests, playback, afterPlayback,
                  stageBefore, stageAfter, fullscreen, captures,
                  semanticText: initial, overflow: await page.evaluate(() => document.documentElement.scrollWidth > innerWidth) });
              } catch (e) { failure = e.message; results.push({ name, failure, errors, requests }); }
              console.log(`${name}: ${failure || 'captured'}`);
              await context.close();
              await fs.writeFile(path.join(out, 'report.json'), JSON.stringify({ evidence: 'local production artifact with deterministic API/media fixtures', webRoot, results }, null, 2));
            }
    } finally { await browser.close(); }
  }
} finally { await new Promise(resolve => server.close(resolve)); }
