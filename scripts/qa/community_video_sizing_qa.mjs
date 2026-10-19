// Community video stage sizing, measured in a real browser against a production
// Flutter web artifact with deterministic local API/media fixtures (no live
// credentials, no writes). It measures the <video> element the browser actually
// paints, the displayed picture inside it (videoWidth/videoHeight + object-fit)
// and the stage height over time (layout shift).
//
// QA_WEB_ROOT  built web root (default build/web)
// QA_MEDIA_ROOT directory with portrait|portrait45|square|landscape|ultrawide
//               .webm/.png and gallery-image.png
// QA_OUT       output directory (report.json + PNGs)
// QA_BROWSERS  chromium,firefox   QA_WIDTHS 390   QA_THEME light
// QA_CASES     portrait,portrait45,square,landscape,ultrawide,mixed
// QA_LEGACY    bare (no aspect, no poster; default) | poster | aspect
// QA_MOTION    no-preference (default) | reduce
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
const out = path.resolve(process.env.QA_OUT || path.join(root, 'output/playwright/community-video-sizing'));
const port = Number(process.env.QA_PORT || 8897);
const origin = `http://127.0.0.1:${port}`;
const mediaHost = 'https://qa-media.kubus.site';
const list = (name, fallback) => (process.env[name] || fallback).split(',').map(s => s.trim()).filter(Boolean);
const legacy = process.env.QA_LEGACY || 'bare';
const aspects = { portrait: 9 / 16, portrait45: 4 / 5, square: 1, landscape: 16 / 9, ultrawide: 21 / 9 };

const ownerId = '22222222-2222-4222-8222-222222222222';
const wallet = 'ArtistWallet111111111111111111111111111111111';
const author = {
  id: ownerId, userId: ownerId, user_id: ownerId, walletAddress: wallet,
  username: 'visual-qa-owner', displayName: 'Visual QA', avatar: `${mediaHost}/portrait.png`,
};
const videoUrl = (shape) => {
  const base = `${mediaHost}/${shape}.webm`;
  const poster = encodeURIComponent(`${mediaHost}/${shape}.png`);
  if (legacy === 'poster') return `${base}#kubus-media=video&kubus-poster=${poster}`;
  if (legacy === 'aspect') return `${base}#kubus-media=video&kubus-aspect=${aspects[shape]}&kubus-poster=${poster}`;
  return base;
};
const postFor = (caseName) => {
  const shape = caseName === 'mixed' ? 'portrait' : caseName;
  const mediaUrls = caseName === 'mixed'
    ? [videoUrl('portrait'), `${mediaHost}/gallery-image.png`, videoUrl('landscape')]
    : [videoUrl(shape)];
  const now = new Date().toISOString();
  return {
    id: '66666666-6666-4666-8666-666666666660', author, content: `${caseName} video QA`,
    category: 'art', tags: [], mediaUrls, postType: 'post', timestamp: now, createdAt: now,
    stats: { likes: 0, comments: 0, shares: 0 },
  };
};

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

// In-page helpers, injected once. Everything reads the live DOM.
const pageHelpers = () => {
  const deep = (r) => [...r.querySelectorAll('*')].flatMap(el => [el, ...(el.shadowRoot ? deep(el.shadowRoot) : [])]);
  window.__kv = {
    videos: () => deep(document).filter(v => v.tagName === 'VIDEO'),
    stage: () => {
      const nodes = deep(document).filter(el => /^Media \d+ of \d+$/.test(el.getAttribute?.('aria-label') || ''));
      return nodes[0] || null;
    },
    snapshot() {
      const s = this.stage();
      const r = s ? s.getBoundingClientRect() : null;
      const v = this.videos()[0];
      // The semantics rect is clipped to the viewport; a clip that already
      // extends past the fold is measured through its own video frame instead.
      const clipped = !!r && (r.y < 1 || r.y + r.height >= innerHeight - 1);
      let video = null;
      if (v) {
        const vr = v.getBoundingClientRect();
        const fit = getComputedStyle(v).objectFit;
        const vw = v.videoWidth, vh = v.videoHeight;
        let pic = { x: vr.x, y: vr.y, w: vr.width, h: vr.height };
        if (vw > 0 && vh > 0 && fit !== 'fill' && fit !== 'cover') {
          const scale = Math.min(vr.width / vw, vr.height / vh);
          pic = { x: vr.x + (vr.width - vw * scale) / 2, y: vr.y + (vr.height - vh * scale) / 2, w: vw * scale, h: vh * scale };
        }
        video = { rect: { x: vr.x, y: vr.y, w: vr.width, h: vr.height }, vw, vh, fit,
          paused: v.paused, muted: v.muted, t: v.currentTime, ready: v.readyState, picture: pic };
      }
      // Clipped with no video frame yet (semantics update a frame before the platform view): unknown.
      const effH = r ? (clipped ? (video ? Math.max(r.height, video.rect.h) : null) : r.height) : null;
      return { stage: r ? { x: r.x, y: r.y, w: r.width, h: effH, rawH: r.height, clipped } : null, video, videos: this.videos().length };
    },
  };
  window.__kvSamples = [];
  const start = performance.now();
  const tick = () => {
    const snap = window.__kv.snapshot();
    window.__kvSamples.push({ t: Math.round(performance.now() - start), h: snap.stage?.h ?? null,
      w: snap.stage?.w ?? null, vw: snap.video?.vw ?? 0, picW: snap.video?.picture.w ?? null });
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
};

const results = [];
try {
  for (const browserName of list('QA_BROWSERS', 'chromium')) {
    const browser = await playwright[browserName].launch({ headless: true });
    try {
      for (const width of list('QA_WIDTHS', '390').map(Number)) {
        for (const caseName of list('QA_CASES', 'portrait,portrait45,square,landscape,ultrawide,mixed')) {
          const motion = process.env.QA_MOTION || 'no-preference';
          const theme = process.env.QA_THEME || 'light';
          const height = width < 768 ? 844 : 900;
          const label = `${browserName}-${legacy}-${motion}-${width}-${caseName}`;
          const context = await browser.newContext({ viewport: { width, height }, colorScheme: theme,
            reducedMotion: motion, locale: 'en-US' });
          const page = await context.newPage();
          const errors = [];
          let mediaFetches = 0;
          page.on('pageerror', e => errors.push(e.message));
          const post = postFor(caseName);
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
                if (file.endsWith('.webm')) mediaFetches++;
                return route.fulfill({ status: 200, headers: cors, contentType: file.endsWith('.png') ? 'image/png' : 'video/webm', body });
              } catch { return route.fulfill({ status: 404, headers: cors, body: '' }); }
            }
            if (url.hostname === 'api.kubus.site') {
              let data = [];
              if (/\/community\/posts\/[a-z0-9-]+$/.test(url.pathname)) data = post;
              else if (/\/community\/(posts|art-feed)/.test(url.pathname)) data = [post];
              else if (url.pathname.endsWith('/config')) data = { communityMultiMediaEnabled: true };
              return route.fulfill({ status: 200, headers: cors, contentType: 'application/json',
                body: JSON.stringify({ success: true, data }) });
            }
            return route.fulfill({ status: 404, headers: cors, body: '' });
          });
          await context.addInitScript(pageHelpers);
          const record = { label, browser: browserName, width, viewportHeight: height, case: caseName, legacy, motion, theme };
          try {
            await page.goto(`${origin}/community?lang=en`, { waitUntil: 'domcontentloaded' });
            await page.waitForSelector('flutter-view', { timeout: 90000 });
            // Turn semantics on as early as the shell allows so the stage can be
            // sampled from before its first video frame.
            await page.waitForFunction(() => !!document.querySelector('flt-semantics-placeholder'), null, { timeout: 60000 });
            await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
            await page.waitForFunction(() => !!window.__kv.stage(), null, { timeout: 30000 });
            await page.waitForTimeout(300);
            record.before = await page.evaluate(() => window.__kv.snapshot());
            await page.screenshot({ path: path.join(out, `${label}-before.png`) });

            // Muted autoplay starts by itself once the clip is clearly on screen
            // (off under reduced motion); otherwise press the clip's own Play.
            const play = page.getByRole('button', { name: /^Play video$|^Pause video$/ }).first();
            if (process.env.QA_DEBUG) console.log(await page.locator('body').ariaSnapshot());
            if (process.env.QA_DEBUG_SCROLL) {
              await page.mouse.move(width / 2, 500); await page.mouse.wheel(0, Number(process.env.QA_DEBUG_SCROLL));
              for (let i = 0; i < 10; i++) {
                await page.waitForTimeout(500);
                const d = await page.evaluate(() => window.__kv.snapshot());
                console.log(i, JSON.stringify({ st: d.stage, v: d.video && { r: d.video.rect, vw: d.video.vw, p: d.video.paused, t: d.video.t } }));
              }
            }
            await page.waitForTimeout(2500);
            let snap = await page.evaluate(() => window.__kv.snapshot());
            let clicked = false;
            if (!(snap.video && snap.video.vw > 0 && !snap.video.paused)) {
              const box = await play.boundingBox({ timeout: 3000 }).catch(() => null);
              if (box) {
                record.playButtonLabel = await play.getAttribute('aria-label').catch(() => null);
                await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2); clicked = true;
              }
            }
            record.clickedPlay = clicked;
            await page.waitForFunction(() => { const s = window.__kv.snapshot(); return s.video && s.video.vw > 0 && s.video.ready >= 2; },
              null, { timeout: 20000 }).catch(() => {});
            await page.waitForTimeout(3200); // ~3 s layout-shift window after init
            const samples = await page.evaluate(() => window.__kvSamples);
            const settleStage = (await page.evaluate(() => window.__kv.snapshot())).stage;
            if (settleStage && settleStage.y > 160) {
              await page.mouse.move(width / 2, 400); await page.mouse.wheel(0, settleStage.y - 120);
              await page.waitForTimeout(900);
            }
            record.after = await page.evaluate(() => window.__kv.snapshot());
            await page.screenshot({ path: path.join(out, `${label}-after.png`) });

            const heights = [];
            for (const s of samples) {
              if (s.h == null) continue;
              if (!heights.length || Math.abs(heights[heights.length - 1].h - s.h) > 0.5) heights.push({ t: s.t, h: Math.round(s.h * 10) / 10 });
            }
            // distinct height plateaus and direction reversals after the player initialised
            const firstVideo = samples.find(s => s.vw > 0);
            const settled = samples.filter(s => s.h != null).slice(-60).map(s => s.h);
            const dirs = [];
            for (let i = 1; i < heights.length; i++) dirs.push(Math.sign(heights[i].h - heights[i - 1].h));
            record.layout = {
              firstVideoFrameMs: firstVideo ? firstVideo.t : null,
              heightPlateaus: heights.length, heightTimeline: heights.slice(0, 40),
              reversals: dirs.reduce((n, d, i) => n + (i > 0 && d !== 0 && dirs[i - 1] !== 0 && d !== dirs[i - 1] ? 1 : 0), 0),
              finalTailRange: settled.length ? Math.round((Math.max(...settled) - Math.min(...settled)) * 100) / 100 : null,
              startHeight: heights[0]?.h ?? null, endHeight: heights[heights.length - 1]?.h ?? null,
            };

            if (caseName === 'mixed') {
              const heightsByPage = [];
              { const st = (await page.evaluate(() => window.__kv.snapshot())).stage; heightsByPage.push({ page: 1, x: st?.x, y: st?.y, w: st?.w, h: st?.h }); }
              record.mixed = { stageByPage: heightsByPage };
              for (let p = 2; p <= 3; p++) {
                const stage = page.getByRole('group', { name: /^Media \d+ of \d+$/ }).or(page.getByRole('button', { name: /^Media \d+ of \d+$/ })).first();
                const b = await stage.boundingBox();
                if (!b) break;
                await page.mouse.move(b.x + b.width - 24, b.y + b.height / 2); await page.waitForTimeout(400);
                const next = page.getByRole('button', { name: /Next media/ }).first();
                const nb = await next.boundingBox({ timeout: 1500 }).catch(() => null);
                if (nb) await page.mouse.click(nb.x + nb.width / 2, nb.y + nb.height / 2);
                await page.waitForTimeout(1800);
                // A video page is a group, an image page a button.
                const current = page.getByRole('group', { name: new RegExp(`^Media ${p} of [0-9]+$`) })
                  .or(page.getByRole('button', { name: new RegExp(`^Media ${p} of [0-9]+$`) })).first();
                const cb = await current.boundingBox().catch(() => null);
                heightsByPage.push({ page: p, x: cb?.x, y: cb?.y, w: cb?.width, h: cb?.height });
                await page.screenshot({ path: path.join(out, `${label}-page-${p}.png`) });
              }
            }
            if (caseName === 'mixed') {
              const rows = record.mixed.stageByPage;
              const w0 = rows[0].w;
              record.mixedCheck = {
                heights: rows.map(r => r.h), expectedHeight: w0 * 3 / 4,
                pass: rows.length === 3 && rows.every(r => Math.abs(r.h - w0 * 3 / 4) <= 1),
              };
            }
            const first = record.after;
            if (caseName !== 'mixed' && first.video && first.stage) {
              const shortest = Math.min(width, height);
              const cap = height * (shortest < 600 ? 1 : 0.72);
              const aspect = first.video.vw / first.video.vh;
              const expected = Math.min(first.stage.w, cap * aspect);
              record.expected = { stageWidth: first.stage.w, maxStageHeight: cap, aspect, expectedPictureWidth: expected,
                pictureWidth: first.video.picture.w, ratio: first.video.picture.w / expected,
                pass: first.video.picture.w >= 0.9 * expected };
            }
            record.mediaFetches = mediaFetches;
          } catch (e) {
            record.failure = e.message;
            await page.screenshot({ path: path.join(out, `${label}-failure.png`) }).catch(() => {});
          }
          record.errors = errors;
          results.push(record);
          console.log(`${label}: ${record.failure || (record.mixedCheck ? `heights ${record.mixedCheck.heights} ${record.mixedCheck.pass ? 'PASS' : 'FAIL'}` : record.expected ? `ratio ${record.expected.ratio.toFixed(3)} ${record.expected.pass ? 'PASS' : 'FAIL'}` : 'measured')}`);
          await context.close();
          await fs.writeFile(path.join(out, 'report.json'), JSON.stringify({ webRoot, results }, null, 2));
        }
      }
    } finally { await browser.close(); }
  }
} finally { await new Promise(resolve => server.close(resolve)); }
