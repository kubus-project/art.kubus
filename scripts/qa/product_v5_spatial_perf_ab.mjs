// Wave 5B controlled web performance experiment (A/B/C).
//
// Measures the SAME camera path against several prebuilt Flutter web bundles
// served from this process, with every external GET (API, basemap tiles,
// glyphs, covers) recorded once to disk and replayed afterwards, so the
// configurations see byte-identical data and network cost drops out.
//
//   A  current dev          (MapLibre GL JS 4.7.1, flat)
//   B  Wave 5B, globe off   (MapLibre GL JS 5.x, flat, --dart-define MAP_GLOBE_ENABLED=false)
//   C  Wave 5B, globe on    (the production web configuration)
//
//   PERF_CONFIGS="A=/path/A,B=/path/B,C=/path/C" PERF_RUNS=5 \
//     node scripts/qa/product_v5_spatial_perf_ab.mjs
//
// Env: PERF_VIEWPORTS=1440x900,390x844  PERF_BROWSER=chromium|firefox
//      PERF_GL=swiftshader|hardware (chromium only)  PERF_LABEL=perf-ab
//      PERF_ORDER=interleave|sequential  PERF_API=https://api.kubus.site
// Output: output/playwright/spatial/<label>/report.json + summary.txt
//
// What is recorded per run: requestAnimationFrame deltas per camera segment
// (zoom-in, pan at street zoom, zoom-out), long tasks, the CPU time MapLibre
// spends inside Map._render, GeoJSONSource.setData calls (count, duration,
// payload size), addImage calls, feature and image counts, and cover image
// traffic. The rAF numbers include GPU/raster time, `_render` and long tasks
// do not, which is how a main-thread cost is told apart from a raster cost.
import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium, firefox } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const label = (process.env.PERF_LABEL || 'perf-ab').trim();
const outDir = path.resolve(rootDir, 'output/playwright/spatial', label);
const fixtureDir = path.resolve(rootDir, 'output/playwright/spatial/perf-fixture');
const markersFile = path.resolve(rootDir, process.env.PERF_MARKERS || 'output/playwright/spatial/perf-fixture-markers.json');
const apiOrigin = process.env.PERF_API || 'https://api.kubus.site';
const runsPerCell = Number(process.env.PERF_RUNS || 5);
const browserName = process.env.PERF_BROWSER || 'chromium';
const glMode = process.env.PERF_GL || 'swiftshader';
const order = process.env.PERF_ORDER || 'interleave';
const configs = (process.env.PERF_CONFIGS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean)
  .map((s, i) => {
    const [name, dir] = s.split('=');
    return { name, dir: path.resolve(dir), port: 8110 + i };
  });
const viewports = (process.env.PERF_VIEWPORTS || '1440x900,390x844').split(',').map((v) => {
  const [width, height] = v.split('x').map(Number);
  return { width, height };
});
if (configs.length === 0) throw new Error('PERF_CONFIGS="A=dir,B=dir,C=dir" is required');

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
  '.map': 'application/json',
};

function serve(config) {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${config.port}`);
    let rel = decodeURIComponent(url.pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(config.dir, rel);
    if (!file.startsWith(config.dir)) return res.writeHead(403).end();
    try {
      if ((await fs.stat(file)).isDirectory()) file = path.join(file, 'index.html');
    } catch {
      file = path.join(config.dir, 'index.html');
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
  return new Promise((resolve) => server.listen(config.port, '127.0.0.1', () => resolve(server)));
}

const corsFor = (request, appUrl) => ({
  'access-control-allow-origin': request.headers().origin || appUrl,
  'access-control-allow-credentials': 'true',
});
const cacheKey = (method, url) => crypto.createHash('sha1').update(`${method} ${url}`).digest('hex');

/** Record-once / replay-forever for every external read; nothing is written upstream. */
async function installFixture(context, config, stats) {
  await fs.mkdir(fixtureDir, { recursive: true });
  const appUrl = `http://127.0.0.1:${config.port}`;
  await context.route('**/*', async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    if (url.origin === appUrl && !url.pathname.startsWith('/api/')) return route.continue();
    if (/\/api\/analytics\b/.test(url.pathname)) return route.fulfill({ status: 204, body: '' });
    if (request.method() === 'OPTIONS') {
      return route.fulfill({
        status: 204,
        headers: {
          'access-control-allow-origin': request.headers().origin || appUrl,
          'access-control-allow-methods': 'GET,OPTIONS',
          'access-control-allow-headers': '*',
          'access-control-allow-credentials': 'true',
        },
        body: '',
      });
    }
    if (request.method() !== 'GET' && request.method() !== 'HEAD') {
      return route.fulfill({ status: 503, body: '' });
    }
    // Marker reads are bounds-keyed, so a moving camera would otherwise ask for
    // different URLs per configuration. Every configuration gets the same fixed
    // dataset (a real capture: 300 markers, 68 of them in Ljubljana).
    if (url.pathname === "/api/art-markers") {
      return route.fulfill({
        status: 200,
        headers: { 'content-type': 'application/json; charset=utf-8', ...corsFor(request, appUrl) },
        body: await fs.readFile(markersFile),
      });
    }
    // The app-origin /api path maps to the real API origin so it caches the same.
    const target = url.origin === appUrl ? `${apiOrigin}${url.pathname}${url.search}` : request.url();
    const key = cacheKey('GET', target);
    const metaFile = path.join(fixtureDir, `${key}.json`);
    const bodyFile = path.join(fixtureDir, `${key}.bin`);
    const cors = {
      'access-control-allow-origin': request.headers().origin || appUrl,
      'access-control-allow-credentials': 'true',
    };
    try {
      const meta = JSON.parse(await fs.readFile(metaFile, 'utf8'));
      const body = await fs.readFile(bodyFile);
      stats.hits += 1;
      return route.fulfill({ status: meta.status, headers: { ...meta.headers, ...cors }, body });
    } catch {
      /* not recorded yet */
    }
    stats.misses += 1;
    try {
      const response = await route.fetch({
        url: target,
        headers: { accept: request.headers().accept || '*/*' },
      });
      const body = await response.body();
      const headers = { ...response.headers() };
      delete headers['content-encoding'];
      delete headers['content-length'];
      delete headers['transfer-encoding'];
      if (response.status() === 200) {
        await fs.writeFile(bodyFile, body);
        await fs.writeFile(metaFile, JSON.stringify({ url: target, status: 200, headers }));
      }
      return route.fulfill({ status: response.status(), headers: { ...headers, ...cors }, body });
    } catch {
      return route.fulfill({ status: 503, body: '' });
    }
  });
}

// Instrumentation installed before any page script. Hooks the MapLibre Map
// prototype as soon as it exists (works for both 4.x and 5.x bundles).
const HOOK = () => {
  window.__maps = [];
  window.__perf = {
    renderMs: [],
    setData: [],
    addImage: 0,
    removeImage: 0,
    longTasks: [],
    segment: 'boot',
  };
  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) {
        window.__perf.longTasks.push({ d: e.duration, t: e.startTime, seg: window.__perf.segment });
      }
    }).observe({ entryTypes: ['longtask'] });
  } catch {}
  window.__perf.readPixels = [];
  for (const Ctx of [window.WebGLRenderingContext, window.WebGL2RenderingContext]) {
    if (!Ctx || !Ctx.prototype.readPixels) continue;
    const readPixels = Ctx.prototype.readPixels;
    Ctx.prototype.readPixels = function (...args) {
      const t0 = performance.now();
      const r = readPixels.apply(this, args);
      window.__perf.readPixels.push({ d: performance.now() - t0, seg: window.__perf.segment });
      return r;
    };
  }
  const timer = setInterval(() => {
    try {
      const proto = window.maplibregl && window.maplibregl.Map && window.maplibregl.Map.prototype;
      if (!proto || proto.__perfHooked) return;
      proto.__perfHooked = true;
      const setStyle = proto.setStyle;
      proto.setStyle = function (...args) {
        if (!window.__maps.includes(this)) window.__maps.push(this);
        return setStyle.apply(this, args);
      };
      if (typeof proto._render === 'function') {
        const render = proto._render;
        proto._render = function (...args) {
          const t0 = performance.now();
          const r = render.apply(this, args);
          window.__perf.renderMs.push({ d: performance.now() - t0, seg: window.__perf.segment });
          return r;
        };
      }
      const addImage = proto.addImage;
      proto.addImage = function (...args) {
        window.__perf.addImage += 1;
        return addImage.apply(this, args);
      };
      const removeImage = proto.removeImage;
      if (removeImage) {
        proto.removeImage = function (...args) {
          window.__perf.removeImage += 1;
          return removeImage.apply(this, args);
        };
      }
      const getSource = proto.getSource;
      proto.getSource = function (id) {
        const source = getSource.call(this, id);
        if (source && typeof source.setData === 'function' && !source.__perfHooked) {
          source.__perfHooked = true;
          const setData = source.setData;
          source.setData = function (data, ...rest) {
            const t0 = performance.now();
            const r = setData.call(this, data, ...rest);
            let features = -1;
            try {
              features = typeof data === 'string' ? -2 : (data.features || []).length;
            } catch {}
            window.__perf.setData.push({
              id,
              d: performance.now() - t0,
              features,
              seg: window.__perf.segment,
            });
            return r;
          };
        }
        return source;
      };
      clearInterval(timer);
    } catch {}
  }, 2);
};

const quantile = (sorted, p) => (sorted.length ? sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * p))] : null);
const fix = (v) => (v == null ? null : Number(v.toFixed(1)));

function summarise(deltas) {
  const s = [...deltas].sort((a, b) => a - b);
  return {
    frames: s.length,
    p50: fix(quantile(s, 0.5)),
    p90: fix(quantile(s, 0.9)),
    p95: fix(quantile(s, 0.95)),
    p99: fix(quantile(s, 0.99)),
    max: fix(s[s.length - 1]),
    over33: s.filter((d) => d > 33.4).length,
    over50: s.filter((d) => d > 50).length,
  };
}

async function oneRun(config, viewport, runIndex) {
  const browserType = browserName === 'firefox' ? firefox : chromium;
  const args =
    browserName === 'chromium'
      ? glMode === 'hardware'
        ? ['--use-angle=d3d11', '--ignore-gpu-blocklist', '--enable-gpu-rasterization']
        : ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
      : [];
  const browser = await browserType.launch({ headless: true, args });
  const stats = { hits: 0, misses: 0 };
  try {
    const context = await browser.newContext({
      viewport,
      deviceScaleFactor: 1,
      colorScheme: 'light',
      locale: 'en-US',
      hasTouch: browserName === 'chromium' && viewport.width <= 480,
      isMobile: false,
    });
    await installFixture(context, config, stats);
    await context.addInitScript(HOOK);
    const page = await context.newPage();
    if (process.env.PERF_DEBUG) {
      page.on('console', (m) => ['error', 'warning'].includes(m.type()) && console.log('  [console]', m.text().slice(0, 200)));
      page.on('pageerror', (e) => console.log('  [pageerror]', String(e).slice(0, 300)));
      page.on('response', (r) => r.status() >= 400 && console.log('  [http]', r.status(), r.url().slice(0, 140)));
    }
    await page.goto(`http://127.0.0.1:${config.port}/map`, { waitUntil: 'domcontentloaded' });
    // isStyleLoaded() stays false while any tile is in flight, so wait for the
    // app's own marker layers instead.
    try {
      await page.waitForFunction(
        () => {
          if (!window.__maps.length) return false;
          const m = window.__maps[window.__maps.length - 1];
          return (m.getStyle()?.layers || []).some((l) => l.id.startsWith('kubus_'));
        },
        null,
        { timeout: 90000 },
      );
    } catch (error) {
      await fs.mkdir(outDir, { recursive: true });
      await page.screenshot({ path: path.join(outDir, `fail-${config.name}-${viewport.width}-${runIndex}.png`) });
      throw error;
    }
    // Wait for the marker source to carry features (data + style both ready).
    await page
      .waitForFunction(
        () => {
          const m = window.__maps[window.__maps.length - 1];
          return m.getSource('kubus_markers') && m.querySourceFeatures('kubus_markers').length > 0;
        },
        null,
        { timeout: 60000 },
      )
      .catch(() => {});
    await page.waitForTimeout(6000);
    const info = await page.evaluate(() => {
      const m = window.__maps[window.__maps.length - 1];
      const gl = m.getCanvas().getContext('webgl2') || m.getCanvas().getContext('webgl');
      const ext = gl && gl.getExtension('WEBGL_debug_renderer_info');
      return {
        maplibre: window.maplibregl.getVersion(),
        projection: (m.getProjection && m.getProjection() && m.getProjection().type) || 'mercator',
        renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : 'n/a',
      };
    });
    // Drop boot-time measurements: only the camera path counts.
    await page.evaluate(() => {
      window.__perf.renderMs = [];
      window.__perf.setData = [];
      window.__perf.longTasks = [];
      window.__perf.readPixels = [];
      window.__perf.addImageAtStart = window.__perf.addImage;
    });

    const result = await page.evaluate(
      () =>
        new Promise((resolve) => {
          const map = window.__maps[window.__maps.length - 1];
          const frames = [];
          const counts = [];
          let last = performance.now();
          let running = true;
          const tick = (now) => {
            frames.push({ d: now - last, seg: window.__perf.segment });
            last = now;
            if (running) requestAnimationFrame(tick);
          };
          const snapshot = (seg) => {
            let features = -1;
            try {
              features = map.querySourceFeatures('kubus_markers').length;
            } catch {}
            counts.push({ seg, features, images: map.listImages ? map.listImages().length : -1 });
          };
          const at = (ms, fn) => setTimeout(fn, ms);
          window.__perf.segment = 'zoom-in';
          map.jumpTo({ zoom: 3.5, center: [14.5058, 46.0569] });
          requestAnimationFrame(tick);
          at(400, () => map.easeTo({ zoom: 15, duration: 2500 }));
          at(3000, () => snapshot('zoom-in'));
          at(3200, () => {
            window.__perf.segment = 'pan';
            map.easeTo({ center: [14.5258, 46.0769], duration: 1200 });
          });
          at(4500, () => snapshot('pan'));
          at(4600, () => {
            window.__perf.segment = 'zoom-out';
            map.easeTo({ zoom: 6, duration: 1800 });
          });
          at(6600, () => {
            snapshot('zoom-out');
            running = false;
            frames.shift();
            resolve({ frames, counts });
          });
        }),
    );

    const perf = await page.evaluate(() => window.__perf);
    const cover = await page.evaluate(() => {
      const entries = performance
        .getEntriesByType('resource')
        .filter((e) => /\.(jpe?g|png|webp)(\?|$)/i.test(e.name) && !/cartocdn|gstatic|googleapis/.test(e.name));
      return {
        requests: entries.length,
        decodedKb: Math.round(entries.reduce((s, e) => s + (e.decodedBodySize || 0), 0) / 1024),
      };
    });

    const bySeg = {};
    for (const seg of ['zoom-in', 'pan', 'zoom-out']) {
      bySeg[seg] = summarise(result.frames.filter((f) => f.seg === seg).map((f) => f.d));
    }
    const render = perf.renderMs.map((r) => r.d).sort((a, b) => a - b);
    const setData = perf.setData;
    return {
      config: config.name,
      viewport: `${viewport.width}x${viewport.height}`,
      run: runIndex,
      info,
      all: summarise(result.frames.map((f) => f.d)),
      bySeg,
      render: {
        calls: render.length,
        p50: fix(quantile(render, 0.5)),
        p95: fix(quantile(render, 0.95)),
        max: fix(render[render.length - 1]),
        totalMs: fix(render.reduce((s, v) => s + v, 0)),
      },
      longTasks: {
        count: perf.longTasks.length,
        totalMs: fix(perf.longTasks.reduce((s, t) => s + t.d, 0)),
        max: fix(Math.max(0, ...perf.longTasks.map((t) => t.d))),
      },
      setData: {
        calls: setData.length,
        totalMs: fix(setData.reduce((s, t) => s + t.d, 0)),
        max: fix(Math.max(0, ...setData.map((t) => t.d))),
        maxFeatures: Math.max(-1, ...setData.map((t) => t.features)),
      },
      readPixels: {
        calls: perf.readPixels.length,
        totalMs: fix(perf.readPixels.reduce((s, r) => s + r.d, 0)),
        max: fix(Math.max(0, ...perf.readPixels.map((r) => r.d))),
      },
      images: { addImageDuringPath: perf.addImage - perf.addImageAtStart, removeImage: perf.removeImage },
      counts: result.counts,
      cover,
      fixture: stats,
    };
  } finally {
    await browser.close();
  }
}

const median = (arr) => {
  const s = arr.filter((v) => v != null).sort((a, b) => a - b);
  return s.length ? s[Math.floor(s.length / 2)] : null;
};

const servers = [];
for (const c of configs) servers.push(await serve(c));
await fs.mkdir(outDir, { recursive: true });
const runs = [];
try {
  // One discarded pass per config fills the fixture so measured runs are all replays.
  for (const c of configs) {
    for (const vp of viewports) {
      const warm = await oneRun(c, vp, -1);
      console.log(`warm ${c.name} ${vp.width}: fixture misses=${warm.fixture.misses}`);
    }
  }
  const cells = [];
  for (const vp of viewports) for (let i = 0; i < runsPerCell; i += 1) cells.push({ vp, i });
  for (const { vp, i } of cells) {
    // Interleave A,B,C within each repetition so machine drift hits all equally.
    for (const c of configs) {
      const r = await oneRun(c, vp, i);
      runs.push(r);
      console.log(
        `${r.config} ${r.viewport} #${i}: p50=${r.all.p50} p95=${r.all.p95} p99=${r.all.p99} max=${r.all.max} >50=${r.all.over50} ` +
          `render.p95=${r.render.p95} longTasks=${r.longTasks.count} setData=${r.setData.calls}/${r.setData.totalMs}ms ` +
          `feat=${r.counts.map((x) => x.features).join('/')} img=${r.counts.map((x) => x.images).join('/')} ` +
          `miss=${r.fixture.misses} ${r.info.maplibre} ${r.info.projection}`,
      );
    }
  }
} finally {
  for (const s of servers) s.close();
}

// Median of per-run statistics for each config x viewport.
const lines = [`# A/B/C web performance (${browserName}, ${glMode})`, `# runs per cell: ${runsPerCell}`, ''];
const summary = [];
for (const vp of viewports) {
  const key = `${vp.width}x${vp.height}`;
  lines.push(`## ${key}`);
  for (const c of configs) {
    const cell = runs.filter((r) => r.config === c.name && r.viewport === key);
    if (!cell.length) continue;
    const m = (get) => median(cell.map(get));
    const row = {
      config: c.name,
      viewport: key,
      maplibre: cell[0].info.maplibre,
      projection: cell[0].info.projection,
      renderer: cell[0].info.renderer,
      p50: m((r) => r.all.p50),
      p90: m((r) => r.all.p90),
      p95: m((r) => r.all.p95),
      p99: m((r) => r.all.p99),
      max: m((r) => r.all.max),
      over33: m((r) => r.all.over33),
      over50: m((r) => r.all.over50),
      frames: m((r) => r.all.frames),
      renderP50: m((r) => r.render.p50),
      renderP95: m((r) => r.render.p95),
      renderTotalMs: m((r) => r.render.totalMs),
      longTasks: m((r) => r.longTasks.count),
      longTaskMs: m((r) => r.longTasks.totalMs),
      setDataCalls: m((r) => r.setData.calls),
      setDataMs: m((r) => r.setData.totalMs),
      addImage: m((r) => r.images.addImageDuringPath),
      readPixelsCalls: m((r) => r.readPixels.calls),
      readPixelsMs: m((r) => r.readPixels.totalMs),
      featuresAtZoomIn: m((r) => r.counts[0]?.features),
      featuresAtPan: m((r) => r.counts[1]?.features),
      imagesAtEnd: m((r) => r.counts[2]?.images),
      coverRequests: m((r) => r.cover.requests),
      coverKb: m((r) => r.cover.decodedKb),
      segP95: Object.fromEntries(['zoom-in', 'pan', 'zoom-out'].map((s) => [s, m((r) => r.bySeg[s].p95)])),
      segOver50: Object.fromEntries(['zoom-in', 'pan', 'zoom-out'].map((s) => [s, m((r) => r.bySeg[s].over50)])),
      p95Spread: [Math.min(...cell.map((r) => r.all.p95)), Math.max(...cell.map((r) => r.all.p95))],
    };
    summary.push(row);
    lines.push(
      `${c.name} [${row.maplibre} ${row.projection}] p50=${row.p50} p90=${row.p90} p95=${row.p95} p99=${row.p99} max=${row.max} ` +
        `>33=${row.over33} >50=${row.over50} frames=${row.frames} | _render p50=${row.renderP50} p95=${row.renderP95} total=${row.renderTotalMs}ms ` +
        `| longtasks=${row.longTasks} (${row.longTaskMs}ms) | setData=${row.setDataCalls}x ${row.setDataMs}ms | addImage=${row.addImage} | readPixels=${row.readPixelsCalls}x ${row.readPixelsMs}ms ` +
        `| feat(z-in/pan)=${row.featuresAtZoomIn}/${row.featuresAtPan} images=${row.imagesAtEnd} | covers=${row.coverRequests} ${row.coverKb}KB ` +
        `| segP95 ${JSON.stringify(row.segP95)} seg>50 ${JSON.stringify(row.segOver50)} | p95 spread ${row.p95Spread.join('..')} | gl=${row.renderer}`,
    );
  }
  lines.push('');
}
await fs.writeFile(path.join(outDir, 'report.json'), JSON.stringify({ browserName, glMode, runsPerCell, summary, runs }, null, 1));
await fs.writeFile(path.join(outDir, 'summary.txt'), lines.join('\n'));
console.log(lines.join('\n'));
