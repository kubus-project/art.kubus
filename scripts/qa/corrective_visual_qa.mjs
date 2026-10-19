// Production Flutter artifact, deterministic local API/media fixtures. No live
// credentials or writes. Generated clips are QA evidence, never product data.
// QA_WEB_ROOT, QA_MEDIA_ROOT, QA_OUT, QA_BROWSERS, QA_WIDTHS, QA_THEMES,
// QA_LOCALES, QA_MOTION, QA_PATH, QA_OWNER configure the bounded matrix.
// QA_LEGACY_VIDEO=bare|poster serves clips without a recorded aspect.
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
const entryUrl = (pathname, locale) => {
  const language = locale.split('-')[0].toLowerCase();
  const url = new URL(pathname, origin);
  const segments = url.pathname.split('/');
  // Bare shell routes (/community, /map, ...) are the only entries the app wraps
  // in AppInitializer. A language prefix exists only for public entity pages, so
  // `/sl/community` falls through to the default entry (the Map and its first-run
  // coach card) and is not an entry a Slovenian user can reach. Those routes
  // select the language with `lang` alone.
  const shellRoutes = ['community', 'map', 'main', 'analytics'];
  if (['en', 'sl'].includes(segments[1])) {
    if (language === 'sl') segments[1] = 'sl';
  } else if (language === 'sl' && !shellRoutes.includes(segments[1])) {
    segments.splice(1, 0, 'sl');
  }
  url.pathname = segments.join('/');
  url.searchParams.set('lang', language);
  return url.toString();
};
const list = (name, fallback) => (process.env[name] || fallback).split(',');
const ownerId = '22222222-2222-4222-8222-222222222222';
const visitorId = '33333333-3333-4333-8333-333333333333';
const artworkId = '11111111-1111-4111-8111-111111111111';
const groupId = '99999999-9999-4999-8999-999999999999';
const wallet = 'ArtistWallet111111111111111111111111111111111';
const mediaHost = 'https://qa-media.kubus.site';
const profile = (id) => ({
  id, userId: id, user_id: id, walletAddress: id === ownerId ? wallet : id,
  username: id === ownerId ? 'visual-qa-owner' : 'visual-qa-visitor',
  displayName: id === ownerId ? 'Alexandra Katarina Longname' : 'Visitor Artist',
  bio: 'Browser fixture for the 0.8.3 visual regression pass.',
  avatar: `${mediaHost}/artwork.png`,
  coverImage: `${mediaHost}/artwork.png`,
  postsCount: 4, posts_count: 4,
  isArtist: true, isInstitution: true, isVerified: true,
  preferences: { privacy: 'public', language: 'en', persona: 'creator' },
  createdAt: '2026-01-10T10:00:00Z', updatedAt: '2026-10-01T10:00:00Z',
});
const shapes = { portrait: 9 / 16, landscape: 16 / 9, square: 1, ultrawide: 21 / 9 };
const group = { id: groupId, name: 'Fixture Group', slug: 'fixture-group',
  description: 'Local browser fixture; no production group is created.',
  isPublic: true, ownerWallet: visitorId, memberCount: 3,
  isMember: false, isOwner: false, coverImage: `${mediaHost}/artwork.png` };
const artwork = { id: artworkId, title: 'Recorded Artwork', artist: 'Recorded Artist',
  description: 'QA fixture: artist differs from uploader.', artistName: 'Recorded Artist',
  metadata: { artistUserId: ownerId }, imageUrl: `${mediaHost}/artwork.png`,
  latitude: 46.0569, longitude: 14.5058, isPublic: true, isActive: true,
  createdAt: '2026-01-01T00:00:00Z' };
const posts = Object.entries(shapes).filter(([shape]) => !process.env.QA_SHAPE || process.env.QA_SHAPE === shape).map(([shape, aspect], i) => ({
  id: `66666666-6666-4666-8666-66666666666${i}`,
  author: profile(process.env.QA_AUTHOR === 'visitor' ? visitorId : i === 0 ? ownerId : visitorId),
  content: `${shape} video — #Art #Ljubljana`, category: 'art', tags: ['Art', 'Ljubljana'],
  // QA_LEGACY_VIDEO reproduces posts published before geometry was recorded:
  // 'bare' is the plain file URL, 'poster' keeps only the video and poster hints.
  mediaUrls: [process.env.QA_LEGACY_VIDEO === 'bare'
    ? `${mediaHost}/${shape}.webm`
    : process.env.QA_LEGACY_VIDEO === 'poster'
      ? `${mediaHost}/${shape}.webm#kubus-media=video&kubus-poster=${encodeURIComponent(`${mediaHost}/${shape}.png`)}`
      : `${mediaHost}/${shape}.webm#kubus-media=video&kubus-aspect=${aspect}&kubus-poster=${encodeURIComponent(`${mediaHost}/${shape}.png`)}`],
  timestamp: new Date(Date.now() - i * 60000).toISOString(),
  createdAt: new Date(Date.now() - i * 60000).toISOString(),
  artwork: { id: artworkId, title: 'Recorded Artwork', artist: 'Recorded Artist' },
  subjectType: 'artwork', subjectId: artworkId,
  location: { name: 'Ljubljana', lat: 46.0569, lng: 14.5058 },
  stats: { likes: 2, comments: 0, shares: 0 },
}));
if (process.env.QA_SAME_ARTWORK === 'true') posts.unshift({ ...posts[0],
  id: '77777777-7777-4777-8777-777777777777', content: 'Still view of the same recorded artwork',
  mediaUrls: [`${mediaHost}/artwork.png`] });
if (process.env.QA_MEDIA_MODE === 'mixed') posts[0].mediaUrls.push(`${mediaHost}/gallery-image.png`);
if (process.env.QA_MEDIA_MODE === 'video-pair' && posts.length) {
  const landscape = 16 / 9;
  posts[0].mediaUrls.push(`${mediaHost}/landscape.webm#kubus-media=video&kubus-aspect=${landscape}&kubus-poster=${encodeURIComponent(`${mediaHost}/landscape.png`)}`);
}
if (process.env.QA_MEDIA_MODE === 'quoted' && posts.length) {
  const originalPost = { ...posts[0], author: profile(visitorId),
    content: 'Original portrait video', category: 'art' };
  posts.splice(0, posts.length, { ...posts[0],
    id: '88888888-8888-4888-8888-888888888888', content: 'Quoted art video',
    mediaUrls: [], postType: 'repost', originalPostId: originalPost.id, originalPost });
}

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
              const requests = []; const mediaRequests = []; const errors = []; const writesBlocked = [];
              page.on('pageerror', e => errors.push(e.message));
              await context.route('**/*', async route => {
                const request = route.request(); const url = new URL(request.url());
                if (url.origin === origin || url.protocol === 'blob:' || url.protocol === 'data:') return route.continue();
                if (url.origin === mediaHost) {
                  const filename = path.basename(url.pathname);
                  mediaRequests.push(filename);
                  const fixtureFilename = filename === 'gallery-image.png' ? 'artwork.png' : filename;
                  try { return route.fulfill({ status: 200, contentType: filename.endsWith('.png') ? 'image/png' : 'video/webm', body: await fs.readFile(path.join(mediaRoot, fixtureFilename)) }); }
                  catch { return route.fulfill({ status: 404, body: '' }); }
                }
                if (url.pathname.startsWith('/api/')) {
                  requests.push({ method: request.method(), path: url.pathname, search: url.search });
                  if (!['GET', 'HEAD', 'OPTIONS'].includes(request.method())) writesBlocked.push(url.pathname);
                  let data = [];
                  if (/\/profiles\/.+\/posts$/.test(url.pathname)) data = posts;
                  else if (/\/profiles\//.test(url.pathname)) data = profile(url.pathname.includes(visitorId) ? visitorId : ownerId);
                  else if (/\/auth\/.*(me|session)/.test(url.pathname)) data = { user: profile(ownerId), profile: profile(ownerId) };
                  else if (/\/community\/posts\/[a-z0-9-]+$/.test(url.pathname)) data = posts[0];
                  else if (/\/community\/(posts|art-feed)/.test(url.pathname)) data = posts;
                  else if (url.pathname === '/api/groups') data = [group];
                  else if (url.pathname.endsWith(`/groups/${groupId}/posts`)) data = posts;
                  else if (url.pathname.includes(`/groups/${groupId}`)) data = group;
                  else if (/\/stats\/user\//.test(url.pathname)) data = {
                    entityType: 'user', entityId: ownerId, scope: 'public',
                    counters: { posts: 4, followers: 0, following: 0, publicStreetArtAdded: 0 },
                    metrics: ['posts', 'followers', 'following', 'publicStreetArtAdded'],
                    generatedAt: new Date().toISOString() };
                  else if (/\/artworks\//.test(url.pathname)) data = artwork;
                  else if (url.pathname === '/api/artworks') data = [artwork];
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
                // Mobile cold entry can open the Map tab, whose first-run coach
                // card would cover the surface under test.
                localStorage.setItem('flutter.map_onboarding_mobile_seen_v2', JSON.stringify(true));
              }, { ownerId, wallet });
              let failure;
              let stageBeforeActivation;
              const pageSwitches = [];
              try {
                await page.goto(entryUrl(process.env.QA_PATH || '/community', locale), { waitUntil: 'domcontentloaded' });
                await page.waitForSelector('flutter-view', { timeout: 60000 });
                await page.waitForTimeout(10000);
                const placeholder = page.locator('flt-semantics-placeholder');
                if (await placeholder.count()) await placeholder.evaluate(el => el.click());
                await page.waitForTimeout(1500);
                if (process.env.QA_PRETAB) {
                  const tab = page.getByRole('tab', { name: new RegExp(process.env.QA_PRETAB), exact: true }).first();
                  const box = await tab.boundingBox();
                  if (!box) throw new Error('Discovery tab missing');
                  await page.mouse.click(box.x + box.width/2, box.y + box.height/2);
                  await page.waitForTimeout(3000);
                }
                const preopenSteps = (process.env.QA_PREOPEN_STEPS || process.env.QA_PREOPEN || '')
                  .split('|').map(step => step.trim()).filter(Boolean);
                for (const preopenStep of preopenSteps) {
                  const named = page.getByRole('button', { name: new RegExp(preopenStep) }).first();
                  const target = await named.count() ? named : page.getByText(preopenStep, { exact: true }).first();
                  const box = await target.boundingBox({ timeout: 2000 }).catch(() => null);
                  if (!box) {
                    await fs.writeFile(path.join(out, `${name}-preopen-failure.yml`), await page.locator('body').ariaSnapshot());
                    throw new Error(`Navigation entry missing: ${preopenStep}`);
                  }
                  await page.mouse.click(box.x+box.width/2, box.y+box.height/2);
                  await page.waitForTimeout(3000);
                }
                await page.screenshot({ path: path.join(out, `${name}-initial.png`) });
                const initial = await page.locator('body').ariaSnapshot();
                await fs.writeFile(path.join(out, `${name}-initial.yml`), initial);
                const mediaStage = page.getByRole('group', { name: /^Media 1 of \d+$/ }).first();
                const stageBefore = await mediaStage.count() ? await mediaStage.boundingBox() : null;
                // Caller supplies a semantic label for bounded navigation QA.
                if (process.env.QA_CLICK) {
                  const isPlay = process.env.QA_CLICK === 'Play video';
                  const target = page.getByRole(process.env.QA_CLICK_ROLE || 'button', { name: new RegExp(isPlay ? 'Play video|Pause video' : process.env.QA_CLICK) }).first();
                  for (let attempt = 0; isPlay && !(await target.count()) && attempt < 8; attempt++) {
                    await page.mouse.move(width / 2, 500); await page.mouse.wheel(0, 350);
                    await page.waitForTimeout(500);
                  }
                  let box = await target.boundingBox();
                  if (!box) throw new Error(`Missing action: ${process.env.QA_CLICK}`);
                  for (let attempt = 0; attempt < 8 && (box.y + box.height / 2 > (width < 768 ? 720 : 780) || box.y < 80); attempt++) {
                    await page.mouse.move(width / 2, 500);
                    await page.mouse.wheel(0, box.y < 80 ? -350 : 350);
                    await page.waitForTimeout(500);
                    box = await target.boundingBox();
                    if (!box) throw new Error('Action disappeared while scrolling');
                  }
                  const extraScroll = Number(process.env.QA_SCROLL_STAGE || 0);
                  if (extraScroll > 0) {
                    await page.mouse.move(width / 2, 500);
                    await page.mouse.wheel(0, extraScroll);
                    await page.waitForTimeout(500);
                    box = await target.boundingBox();
                    if (!box) throw new Error('Action disappeared while revealing its stage');
                  }
                  stageBeforeActivation = await mediaStage.count() ? await mediaStage.boundingBox() : null;
                  if (!isPlay || /Play video/.test(await target.getAttribute('aria-label') || await target.innerText()))
                    await page.mouse.click(box.x + box.width/2, box.y + box.height/2);
                  await page.waitForTimeout(4000);
                  await page.screenshot({ path: path.join(out, `${name}-action.png`) });
                  const actionText = await page.locator('body').ariaSnapshot();
                  await fs.writeFile(path.join(out, `${name}-action.yml`), actionText);
                  if (process.env.QA_EXPECT_OWNER === 'true' && !/Edit profile|Uredi profil/i.test(actionText))
                    throw new Error('Owner navigation did not reach canonical edit actions');
                  if (process.env.QA_EXPECT_OWNER === 'true' && /button "(Follow|Sledi|Message|Sporoči)"/.test(actionText))
                    throw new Error('Owner profile exposes visitor Follow/Message actions');
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
                if (process.env.QA_CLICK === 'Play video' && (!playback.some((p, i) =>
                  p.readyState >= 2 && !p.paused && afterPlayback[i]?.time > p.time)))
                  throw new Error('Video did not advance through the playback interval');
                const stageAfter = await mediaStage.count() ? await mediaStage.boundingBox() : null;
                const maxViewportHeight = await page.evaluate(() => window.innerHeight);
                const clippedSemanticBounds = stageAfter ? {
                  top: Math.max(0, stageAfter.y),
                  bottom: Math.min(maxViewportHeight, stageAfter.y + stageAfter.height),
                  height: Math.max(0, Math.min(maxViewportHeight, stageAfter.y + stageAfter.height) - Math.max(0, stageAfter.y)),
                } : null;
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
                for (const pageNumber of (process.env.QA_PAGE_SEQUENCE || '')
                  .split(',').map(value => value.trim()).filter(Boolean)) {
                  const pageIndex = Number(pageNumber) - 1;
                  // The carousel is a group on a video page and a button on an image page.
                  const currentStage = page.getByRole('group', { name: /^Media \d+ of \d+$/ }).or(page.getByRole('button', { name: /^Media \d+ of \d+$/ })).first();
                  const currentBounds = await currentStage.boundingBox();
                  if (!currentBounds) throw new Error('Carousel stage missing before requested page switch');
                  const controlX = pageIndex === 0
                    ? currentBounds.x + 24
                    : currentBounds.x + currentBounds.width - 24;
                  const controlY = currentBounds.y + currentBounds.height / 2;
                  await page.mouse.move(controlX, controlY);
                  await page.waitForTimeout(400);
                  const direction = pageIndex === 0 ? 'Previous media' : 'Next media';
                  const arrowButton = page.getByRole('button', { name: new RegExp(direction) }).first();
                  const arrowBounds = await arrowButton.boundingBox({ timeout: 1500 }).catch(() => null);
                  if (arrowBounds) await page.mouse.click(arrowBounds.x + arrowBounds.width / 2,
                    arrowBounds.y + arrowBounds.height / 2);
                  await page.waitForTimeout(800);
                  const stage = page.getByRole('group', { name: /^Media \d+ of \d+$/ }).or(page.getByRole('button', { name: /^Media \d+ of \d+$/ })).first();
                  const stageBounds = await stage.boundingBox();
                  const switchText = await page.locator('body').ariaSnapshot();
                  const totalPages = Number((initial.match(/Media 1 of (\d+)/) || [])[1] || 1);
                  if (!new RegExp(`Art ${pageIndex + 1} \/ ${totalPages}`).test(switchText))
                    throw new Error(`Carousel did not reach media page ${pageIndex + 1}`);
                  const videoRects = await page.evaluate(() => {
                    const deep = root => [...root.querySelectorAll('*')].flatMap(el => [el, ...(el.shadowRoot ? deep(el.shadowRoot) : [])]);
                    return deep(document).filter(v => v.tagName === 'VIDEO').map(v => ({
                      width: v.videoWidth, height: v.videoHeight, time: v.currentTime,
                      paused: v.paused, rect: v.getBoundingClientRect().toJSON() }));
                  });
                  const videoControl = page.getByRole('button', { name: /^(Play|Pause) video$/ }).first();
                  const videoControlBounds = await videoControl.boundingBox().catch(() => null);
                  pageSwitches.push({ page: pageIndex + 1, stage: stageBounds, videoRects, videoControlBounds });
                  await page.screenshot({ path: path.join(out, `${name}-page-${pageIndex + 1}.png`) });
                  await fs.writeFile(path.join(out, `${name}-page-${pageIndex + 1}.yml`), switchText);
                }
                if (process.env.QA_HASHTAG_PROBE === 'true') {
                  const tag = page.getByRole('button', { name: '#Art', exact: true }).first();
                  for (let i = 0; !(await tag.count()) && i < 6; i++) {
                    await page.mouse.move(width/2, 500); await page.mouse.wheel(0, 200);
                    await page.waitForTimeout(300);
                  }
                  let box = await tag.boundingBox();
                  for (let i = 0; box && box.y > 680 && i < 6; i++) {
                    await page.mouse.move(width/2, 500); await page.mouse.wheel(0, 250);
                    await page.waitForTimeout(300); box = await tag.boundingBox();
                  }
                  if (!box) throw new Error('Hashtag control missing');
                  await page.mouse.move(2, 2);
                  await page.screenshot({ path: path.join(out, `${name}-tag-normal.png`) });
                  await page.mouse.move(box.x+box.width/2, box.y+box.height/2);
                  await page.waitForTimeout(200);
                  await page.screenshot({ path: path.join(out, `${name}-tag-hover.png`) });
                  await tag.focus(); await page.waitForTimeout(200);
                  await page.screenshot({ path: path.join(out, `${name}-tag-focus.png`) });
                  await page.mouse.click(box.x+box.width/2, box.y+box.height/2);
                  await page.waitForTimeout(600);
                  await page.screenshot({ path: path.join(out, `${name}-tag-filter.png`) });
                  await fs.writeFile(path.join(out, `${name}-tag-filter.yml`), await page.locator('body').ariaSnapshot());
                }
                const captures = [];
                for (const captureWidth of list('QA_CAPTURE_WIDTHS', String(width)).map(Number)) {
                  await page.setViewportSize({ width: captureWidth, height: captureWidth < 768 ? 844 : 900 });
                  await page.waitForTimeout(700);
                  await page.screenshot({ path: path.join(out, `${name}-width-${captureWidth}.png`) });
                  captures.push({ width: captureWidth, overflow: await page.evaluate(() => document.documentElement.scrollWidth > innerWidth) });
                }
                results.push({ name, errors, writesBlocked, requests, mediaRequests, playback, afterPlayback, pageSwitches,
                  stageBefore, stageBeforeActivation, stageAfter, maxViewportHeight,
                  clippedSemanticBounds, fullscreen, captures,
                  semanticText: initial, overflow: await page.evaluate(() => document.documentElement.scrollWidth > innerWidth) });
              } catch (e) {
                failure = e.message; results.push({ name, failure, errors, requests });
                await page.screenshot({ path: path.join(out, `${name}-failure.png`) }).catch(() => {});
                await fs.writeFile(path.join(out, `${name}-failure.yml`), await page.locator('body').ariaSnapshot()).catch(() => {});
              }
              console.log(`${name}: ${failure || 'captured'}`);
              await context.close();
              await fs.writeFile(path.join(out, 'report.json'), JSON.stringify({ evidence: 'local production artifact with deterministic API/media fixtures', webRoot, results }, null, 2));
            }
    } finally { await browser.close(); }
  }
} finally { await new Promise(resolve => server.close(resolve)); }
