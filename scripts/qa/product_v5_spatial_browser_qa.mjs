// Wave 5B spatial map browser QA.
//
// Serves a prebuilt Flutter web bundle and drives the real map in Chromium and
// Firefox: opening frame, world -> street zoom, drag, rapid wheel, theme swap,
// marker selection state and console health. The MapLibre GL JS instance is
// reached through a prototype hook installed before the app starts, so the
// checks read the renderer's own state (projection, zoom, layers, rendered
// features) rather than guessing from pixels. Screenshots are for the visual
// read; assertions never depend on them.
//
//   QA_WEB_ROOT=build/web QA_LABEL=after node scripts/qa/product_v5_spatial_browser_qa.mjs
//
// Env: QA_BROWSERS=chromium,firefox  QA_VIEWPORTS=1440x900,390x844
//      QA_SCHEMES=light,dark  QA_PATH=/map  QA_PORT=8097
// Output: output/playwright/spatial/<label>/ (screenshots + report.json)
//
// Network: public GETs (API reads, basemap tiles, fonts, CanvasKit) pass
// through; analytics and every write are answered locally so no telemetry
// reaches production and nothing is created.
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium, firefox } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const label = (process.env.QA_LABEL || 'after').trim();
const outDir = path.resolve(rootDir, 'output/playwright/spatial', label);
const port = Number(process.env.QA_PORT || 8097);
const appUrl = `http://127.0.0.1:${port}`;
const startPath = process.env.QA_PATH || '/map';

const list = (name, fallback) =>
  (process.env[name] || fallback).split(',').map((s) => s.trim()).filter(Boolean);
const browsers = list('QA_BROWSERS', 'chromium,firefox');
const viewports = list('QA_VIEWPORTS', '1440x900,390x844').map((v) => {
  const [w, h] = v.split('x').map(Number);
  return { width: w, height: h };
});
const schemes = list('QA_SCHEMES', 'light,dark');

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

function startServer() {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, appUrl);
    let rel = decodeURIComponent(url.pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(webRoot, rel);
    if (!file.startsWith(webRoot)) {
      res.writeHead(403).end();
      return;
    }
    try {
      const stat = await fs.stat(file);
      if (stat.isDirectory()) file = path.join(file, 'index.html');
    } catch {
      file = path.join(webRoot, 'index.html');
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
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}

const apiOrigin = process.env.QA_API_ORIGIN || 'https://api.kubus.site';

async function containNetwork(context) {
  const log = { analyticsSwallowed: 0, writesBlocked: [], failedRequests: [] };
  await context.route('**/*', async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const sameOrigin = url.origin === appUrl;
    const isApi = sameOrigin
      ? url.pathname.startsWith('/api/')
      : url.origin === new URL(apiOrigin).origin;
    if (sameOrigin && !isApi) return route.continue();
    if (isApi) {
      if (/\/api\/analytics\b/.test(url.pathname)) {
        log.analyticsSwallowed += 1;
        return route.fulfill({ status: 204, body: '' });
      }
      if (request.method() === 'GET') {
        try {
          const target = sameOrigin ? `${apiOrigin}${url.pathname}${url.search}` : request.url();
          const response = await route.fetch({
            url: target,
            headers: { accept: request.headers().accept || 'application/json' },
          });
          return route.fulfill({
            response,
            headers: {
              ...response.headers(),
              'access-control-allow-origin': request.headers().origin || appUrl,
              'access-control-allow-credentials': 'true',
            },
          });
        } catch {
          return route.fulfill({ status: 503, body: '' });
        }
      }
      if (request.method() === 'OPTIONS') {
        return route.fulfill({
          status: 204,
          headers: {
            'access-control-allow-origin': request.headers().origin || appUrl,
            'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
            'access-control-allow-headers': '*',
            'access-control-allow-credentials': 'true',
          },
          body: '',
        });
      }
      log.writesBlocked.push(`${request.method()} ${url.pathname}`);
      return route.fulfill({
        status: 503,
        headers: { 'access-control-allow-origin': request.headers().origin || appUrl },
        body: '',
      });
    }
    // Third-party public reads (tiles, fonts, CanvasKit): read-only GETs only.
    if (request.method() === 'GET' || request.method() === 'HEAD') return route.continue();
    log.writesBlocked.push(`${request.method()} ${url.hostname}`);
    return route.fulfill({ status: 204, body: '' });
  });
  context.on('requestfailed', (r) => {
    log.failedRequests.push(`${r.method()} ${r.url().slice(0, 100)}`);
  });
  return log;
}

// Installed before any page script runs: captures every MapLibre Map instance.
const HOOK = () => {
  window.__maps = [];
  // `maplibregl` is assigned before its members exist, so the prototype is
  // patched as soon as `Map` appears (always before the app creates one: the
  // app awaits the runtime promise first).
  const timer = setInterval(() => {
    try {
      const proto = window.maplibregl && window.maplibregl.Map && window.maplibregl.Map.prototype;
      if (!proto || proto.__qaHooked) return;
      proto.__qaHooked = true;
      const original = proto.setStyle;
      proto.setStyle = function (...args) {
        if (!window.__maps.includes(this)) window.__maps.push(this);
        return original.apply(this, args);
      };
      clearInterval(timer);
    } catch {}
  }, 5);
};

const mapState = () =>
  window.__maps.length
    ? (() => {
        const map = window.__maps[window.__maps.length - 1];
        const layers = (map.getStyle()?.layers || []).map((l) => l.id);
        const proj = map.getProjection ? map.getProjection() : null;
        return {
          version: window.maplibregl?.getVersion?.(),
          projection: proj && proj.type,
          zoom: Number(map.getZoom().toFixed(2)),
          // A globe reports the Mercator zoom at the centre latitude; MapLibre
          // constrains the equator zoom, so compare minZoom against this.
          zoomEq: Number(
            (map.getZoom() - Math.log2(Math.cos((map.getCenter().lat * Math.PI) / 180))).toFixed(2),
          ),
          minZoom: map.getMinZoom(),
          center: [Number(map.getCenter().lng.toFixed(3)), Number(map.getCenter().lat.toFixed(3))],
          bearing: Number(map.getBearing().toFixed(1)),
          pitch: Number(map.getPitch().toFixed(1)),
          loaded: map.isStyleLoaded(),
          kubusLayers: layers.filter((id) => id.startsWith('kubus_')),
          maps: window.__maps.length,
        };
      })()
    : null;

async function waitForMap(page, timeoutMs = 90000) {
  await page.waitForFunction(() => window.__maps && window.__maps.length > 0, null, {
    timeout: timeoutMs,
  });
  await page.waitForFunction(
    () => {
      const map = window.__maps[window.__maps.length - 1];
      return map && map.isStyleLoaded() && map.getLayer('kubus_marker_layer');
    },
    null,
    { timeout: timeoutMs },
  );
}

async function settle(page, ms = 2500) {
  await page.waitForTimeout(ms);
}

async function snap(page, name, report) {
  const file = path.join(outDir, `${name}.png`);
  await page.screenshot({ path: file });
  report.screenshots.push(path.relative(rootDir, file).replaceAll('\\', '/'));
}

function check(report, name, ok, detail = '') {
  report.checks.push({ name, ok: Boolean(ok), detail });
  if (!ok) report.failed = true;
}

async function renderedKubusFeatures(page) {
  return page.evaluate(() => {
    const map = window.__maps[window.__maps.length - 1];
    const features = map.queryRenderedFeatures(undefined, { layers: ['kubus_marker_dot_layer'] });
    const clusters = features.filter((f) => f.properties?.kind === 'cluster').length;
    return { dots: features.length, clusters, markers: features.length - clusters };
  });
}


/** Screen point (viewport CSS px) of a rendered marker-kind hitbox feature. */
async function findMarkerTarget(page) {
  return page.evaluate(() => {
    const map = window.__maps[window.__maps.length - 1];
    const rect = map.getCanvas().getBoundingClientRect();
    const features = map.queryRenderedFeatures(undefined, { layers: ['kubus_marker_hitbox_layer'] });
    // The marker nearest the middle of the map: free of the side rail, the
    // controls and the discovery card that sit over the edges.
    const cx = rect.width / 2;
    const cy = rect.height / 2;
    let best = null;
    for (const f of features) {
      if (f.properties?.kind !== 'marker') continue;
      const [lng, lat] = f.geometry.coordinates;
      const p = map.project([lng, lat]);
      const d = (p.x - cx) ** 2 + (p.y - cy) ** 2;
      if (!best || d < best.d) best = { d, f, p };
    }
    if (!best) return null;
    return { id: String(best.f.properties.id), x: rect.left + best.p.x, y: rect.top + best.p.y };
  });
}

async function selectionState(page, id) {
  return page.evaluate((markerId) => {
    const map = window.__maps[window.__maps.length - 1];
    const sourceFeatures = map
      .querySourceFeatures('kubus_markers')
      .filter((f) => String(f.properties?.id) === markerId);
    const opacity = JSON.stringify(map.getPaintProperty('kubus_marker_layer', 'icon-opacity') ?? null);
    return {
      inSource: sourceFeatures.length,
      kind: sourceFeatures[0]?.properties?.kind ?? null,
      opacityPinsSelection: opacity.includes(markerId),
      hasMarkerLayer: Boolean(map.getLayer('kubus_marker_layer')),
      zoom: Number(map.getZoom().toFixed(2)),
    };
  }, id);
}

async function tapAt(page, point, viewport) {
  if (viewport.touch) await page.touchscreen.tap(point.x, point.y);
  else await page.mouse.click(point.x, point.y);
}

/** Select a marker, then prove it stays a visible marker at every zoom level. */
async function selectionContinuity(page, viewport, tag, run) {
  await page.evaluate(() => {
    window.__maps[window.__maps.length - 1].jumpTo({ zoom: 15.5, center: [14.5058, 46.0569] });
  });
  await settle(page, 3500);
  run.streetMix = await sourceIconMix(page);
  run.streetDiag = await page.evaluate(() => {
    const map = window.__maps[window.__maps.length - 1];
    const fs = map.querySourceFeatures('kubus_markers');
    const eo = fs.map((f) => f.properties?.entryOpacity);
    return {
      iconOpacity: JSON.stringify(map.getPaintProperty('kubus_marker_layer', 'icon-opacity')).slice(0, 300),
      layout: JSON.stringify({ vis: map.getLayoutProperty('kubus_marker_layer', 'visibility'), size: map.getLayoutProperty('kubus_marker_layer', 'icon-size') }).slice(0, 200),
      entryOpacityMin: Math.min(...eo),
      entryOpacityMax: Math.max(...eo),
      renderedSymbols: map.queryRenderedFeatures(undefined, { layers: ['kubus_marker_layer'] }).length,
      imagesOk: fs.slice(0, 5).map((f) => [String(f.properties?.icon), map.hasImage(String(f.properties?.icon))]),
    };
  });
  const target = await findMarkerTarget(page);
  if (!target) {
    check(run, `${tag}: a marker is available to select at street scale`, false, 'none rendered');
    return;
  }
  await tapAt(page, { x: target.x, y: target.y - 18 }, viewport);
  await settle(page, 2200);
  const selected = await selectionState(page, target.id);
  check(run, `${tag}: tapping a marker selects it (badge opacity pins its id)`, selected.opacityPinsSelection, JSON.stringify(selected));
  await snap(page, `${tag}-sel-z15`, run);

  const levels = [];
  for (const zoom of [11, 8, 5, 3.2]) {
    await page.evaluate((z) => {
      window.__maps[window.__maps.length - 1].jumpTo({ zoom: z });
    }, zoom);
    await settle(page, 2600);
    const s = await selectionState(page, target.id);
    levels.push({ zoom, ...s });
    await snap(page, `${tag}-sel-z${String(zoom).replace('.', '_')}`, run);
  }
  run.selectionLevels = levels;
  if (viewport.width <= 480) {
    // Phone keeps the selection through gestures; desktop dismisses it by
    // design (anchored overlay), so the zoom-out invariant is a phone check.
    check(
      run,
      `${tag}: the selected marker stays an individual marker at every zoom`,
      levels.every((l) => l.inSource >= 1 && l.kind === 'marker'),
      JSON.stringify(levels.map((l) => [l.zoom, l.inSource, l.kind])),
    );
    check(
      run,
      `${tag}: the badge stays pinned visible for the selection at far zoom`,
      levels.every((l) => l.opacityPinsSelection),
      '',
    );
  }
  return target;
}

/** Theme switch must keep the layers and the selection pin. */
async function themeSwitchKeepsState(page, tag, run, id, scheme) {
  run.step = 'theme-switch';
  const next = scheme === 'dark' ? 'light' : 'dark';
  await page.emulateMedia({ colorScheme: next });
  await settle(page, 4500);
  const state = await page.evaluate(mapState);
  check(
    run,
    `${tag}: all kubus layers are re-installed after the theme switch`,
    state && state.kubusLayers.length >= 5,
    state && state.kubusLayers.join(','),
  );
  if (id) {
    const s = await selectionState(page, id);
    run.afterThemeSwitch = s;
    check(run, `${tag}: the selection pin survives the theme switch`, s.hasMarkerLayer, JSON.stringify(s));
  }
  await snap(page, `${tag}-after-theme-${next}`, run);
  await page.emulateMedia({ colorScheme: scheme });
  await settle(page, 3500);
}


/** Frame pacing while the camera moves: rAF deltas over a scripted zoom + pan. */
async function measureFrames(page) {
  return page.evaluate(
    () =>
      new Promise((resolve) => {
        const map = window.__maps[window.__maps.length - 1];
        const deltas = [];
        let last = performance.now();
        let running = true;
        const tick = (now) => {
          deltas.push(now - last);
          last = now;
          if (running) requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
        map.jumpTo({ zoom: 3.5, center: [14.5, 46] });
        setTimeout(() => map.easeTo({ zoom: 15, duration: 2500 }), 400);
        setTimeout(() => map.easeTo({ center: [14.52, 46.07], duration: 1200 }), 3200);
        setTimeout(() => map.easeTo({ zoom: 6, duration: 1800 }), 4600);
        setTimeout(() => {
          running = false;
          const sorted = deltas.slice(1).sort((a, b) => a - b);
          const q = (p) => sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * p))];
          resolve({
            frames: sorted.length,
            p50: Number(q(0.5).toFixed(1)),
            p95: Number(q(0.95).toFixed(1)),
            max: Number(sorted[sorted.length - 1].toFixed(1)),
            over50ms: sorted.filter((d) => d > 50).length,
          });
        }, 6800);
      }),
  );
}

/** Bytes the page pulled for non-basemap images (the cover budget, measured). */
async function coverTraffic(page) {
  return page.evaluate(() => {
    const entries = performance
      .getEntriesByType('resource')
      .filter((e) => /\.(jpe?g|png|webp)(\?|$)/i.test(e.name) && !/cartocdn|gstatic|googleapis/.test(e.name));
    return {
      requests: entries.length,
      transferBytes: entries.reduce((sum, e) => sum + (e.transferSize || 0), 0),
      decodedBytes: entries.reduce((sum, e) => sum + (e.decodedBodySize || 0), 0),
      // Wikimedia thumbs carry their width in the URL, so the map's covers
      // (requested at 160 logical px) can be told apart from other surfaces.
      byWidth: entries.reduce((acc, e) => {
        const m = e.name.match(/\/(\d+)px-/);
        const key = m ? `${m[1]}px` : 'other';
        acc[key] = acc[key] || { requests: 0, kb: 0 };
        acc[key].requests += 1;
        acc[key].kb += Math.round((e.decodedBodySize || 0) / 1024);
        return acc;
      }, {}),
      sample: entries
        .map((e) => ({ url: e.name.slice(0, 110), kb: Math.round((e.decodedBodySize || 0) / 1024) }))
        .sort((a, b) => b.kb - a.kb)
        .slice(0, 8),
    };
  });
}

/** Simulated WebGL context loss and restore: layers return, no recreate loop. */
async function webglLossRecovery(page, tag, run) {
  const before = await page.evaluate(() => window.__maps.length);
  const lost = await page.evaluate(
    () =>
      new Promise((resolve) => {
        const canvas = window.__maps[window.__maps.length - 1].getCanvas();
        const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
        const ext = gl && gl.getExtension('WEBGL_lose_context');
        if (!ext) return resolve({ supported: false });
        ext.loseContext();
        setTimeout(() => {
          ext.restoreContext();
          resolve({ supported: true });
        }, 1200);
      }),
  );
  if (!lost.supported) {
    run.webglLoss = { supported: false };
    return;
  }
  await settle(page, 7000);
  const after = await page.evaluate(() => ({
    maps: window.__maps.length,
    state: (() => {
      const map = window.__maps[window.__maps.length - 1];
      return {
        kubusLayers: (map.getStyle()?.layers || []).filter((l) => l.id.startsWith('kubus_')).length,
        loaded: map.isStyleLoaded(),
      };
    })(),
  }));
  run.webglLoss = { supported: true, mapsBefore: before, mapsAfter: after.maps, ...after.state };
  check(
    run,
    `${tag}: map recovers from WebGL context loss without a recreate loop`,
    after.maps - before <= 2 && after.state.kubusLayers >= 5,
    JSON.stringify(run.webglLoss),
  );
  await snap(page, `${tag}-after-webgl-loss`, run);
}

/** Basemap tiles unavailable: the product map (markers, UI) must still work. */
async function degradedBasemap(browser, browserName, viewport, scheme, report) {
  const tag = `${browserName}-${viewport.width}x${viewport.height}-${scheme}-offline-tiles`;
  const run = { tag, checks: [], screenshots: [], console: [], failed: false };
  report.runs.push(run);
  const context = await browser.newContext({
    viewport,
    deviceScaleFactor: 1,
    colorScheme: scheme,
    locale: 'en-US',
  });
  await context.addInitScript(HOOK);
  run.network = await containNetwork(context);
  // Fail only the basemap vector tiles / fonts / sprites, not the app or API.
  await context.route(/cartocdn\.com/, (route) => route.abort('failed'));
  const page = await context.newPage();
  page.on('pageerror', (e) => run.console.push(`[pageerror] ${e.message.slice(0, 200)}`));
  try {
    await page.goto(`${appUrl}${startPath}`, { waitUntil: 'domcontentloaded' });
    await waitForMap(page);
    await settle(page, 6000);
    const state = await page.evaluate(mapState);
    const features = await renderedKubusFeatures(page);
    run.degraded = { ...state, ...features };
    check(run, `${tag}: product layers install without basemap tiles`, state.kubusLayers.length >= 5, state.kubusLayers.join(','));
    check(run, `${tag}: no uncaught page error`, run.console.filter((l) => l.startsWith('[pageerror]')).length === 0, run.console.join(' || '));
    await snap(page, `${tag}-01`, run);
  } catch (error) {
    run.failed = true;
    run.error = String(error).slice(0, 300);
    await snap(page, `${tag}-error`, run).catch(() => {});
  } finally {
    await context.close();
  }
}

/** The page must never scroll sideways, whatever the viewport. */
async function noHorizontalOverflow(page, tag, run) {
  const overflow = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
  }));
  check(run, `${tag}: no horizontal page overflow`, overflow.scrollWidth <= overflow.innerWidth + 1, JSON.stringify(overflow));
}


/** What the marker source currently holds, by kind and icon family. */
async function sourceIconMix(page) {
  return page.evaluate(() => {
    const map = window.__maps[window.__maps.length - 1];
    const mix = {};
    const seen = new Set();
    for (const f of map.querySourceFeatures('kubus_markers')) {
      const id = String(f.properties?.id);
      if (seen.has(id)) continue;
      seen.add(id);
      const icon = String(f.properties?.icon);
      const family = icon.startsWith('mc_') ? 'cover' : icon.startsWith('mk_') ? 'marker' : icon.startsWith('cl_') ? 'clusterIcon' : 'blank';
      const key = `${f.properties?.kind}:${family}`;
      mix[key] = (mix[key] || 0) + 1;
    }
    return mix;
  });
}

async function scenario(browserName, viewport, scheme, report) {
  // Only Chromium can emulate a touch device; Firefox phone widths use the mouse.
  viewport = { ...viewport, touch: browserName === 'chromium' && viewport.width <= 480 };
  const browserType = browserName === 'firefox' ? firefox : chromium;
  const browser = await browserType.launch({
    headless: true,
    args:
      browserName === 'chromium'
        ? ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
        : [],
  });
  const tag = `${browserName}-${viewport.width}x${viewport.height}-${scheme}`;
  const run = { tag, checks: [], screenshots: [], console: [], failed: false };
  report.runs.push(run);
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: 1,
    colorScheme: scheme,
    locale: 'en-US',
    ...(viewport.touch ? { isMobile: true, hasTouch: true } : {}),
  });
  await context.addInitScript(HOOK);
  run.network = await containNetwork(context);
  await context.routeWebSocket(/.*/, (ws) => ws.close());
  const page = await context.newPage();
  page.on('console', (m) => {
    const text = m.text();
    if (m.type() === 'error' || /maplibre|webgl|exception/i.test(text)) {
      run.console.push(`[${m.type()}] @${run.step || 'start'} ${text.slice(0, 220)}`);
    }
  });
  page.on('pageerror', (e) => run.console.push(`[pageerror] ${e.message.slice(0, 220)}`));

  try {
    await page.goto(`${appUrl}${startPath}`, { waitUntil: 'domcontentloaded' });
    await waitForMap(page);
    await settle(page, browserName === 'firefox' ? 9000 : 6000);
    const open = await page.evaluate(mapState);
    run.opening = open;
    await snap(page, `${tag}-01-opening`, run);
    check(run, `${tag}: maplibre 5.x`, /^5\./.test(open.version || ''), String(open.version));
    check(
      run,
      `${tag}: globe projection active`,
      open.projection === 'globe' || open.projection === 'vertical-perspective',
      String(open.projection),
    );
    check(run, `${tag}: kubus layers installed`, open.kubusLayers.length >= 5, open.kubusLayers.join(','));

    run.step = 'zoom-sweep';
    // World -> street.
    run.zoomSteps = [];
    for (const z of [2.5, 4, 7, 11, 15, 17]) {
      await page.evaluate((zoom) => {
        const map = window.__maps[window.__maps.length - 1];
        map.jumpTo({ zoom, center: [14.5058, 46.0569] });
      }, z);
      await settle(page, 2200);
      const s = await page.evaluate(mapState);
      const f = await renderedKubusFeatures(page);
      const mix = await sourceIconMix(page);
      run.zoomSteps.push({ z, ...s, ...f, mix });
      // The level of detail is data the renderer actually holds, so assert it:
      // far holds no marker artwork, mid and close hold no blank placeholders.
      const keys = Object.keys(mix);
      if (z <= 4) {
        check(run, `${tag}: far zoom ${z} holds no marker artwork`, !keys.some((k) => /clusterIcon|:marker|:cover/.test(k)), JSON.stringify(mix));
      }
      if (z >= 7) {
        check(run, `${tag}: zoom ${z} holds canonical markers, not far placeholders`, !keys.some((k) => k.endsWith(':blank')), JSON.stringify(mix));
      }
      if (z >= 15) {
        check(run, `${tag}: street zoom ${z} carries artwork covers`, keys.some((k) => k.endsWith(':cover')), JSON.stringify(mix));
      }
      await snap(page, `${tag}-z${String(z).replace('.', '_')}`, run);
    }

    run.step = 'gestures';
    // Gestures: wheel, drag, rapid wheel.
    await page.evaluate(() => {
      window.__maps[window.__maps.length - 1].jumpTo({ zoom: 4, center: [14.5, 46] });
    });
    await settle(page, 1500);
    const cx = viewport.width / 2;
    const cy = viewport.height / 2;
    await page.mouse.move(cx, cy);
    const before = await page.evaluate(mapState);
    for (let i = 0; i < 6; i += 1) {
      await page.mouse.wheel(0, -240);
      await page.waitForTimeout(60);
    }
    await settle(page, 1800);
    const afterWheel = await page.evaluate(mapState);
    check(run, `${tag}: wheel zooms in`, afterWheel.zoom > before.zoom + 0.5, `${before.zoom} -> ${afterWheel.zoom}`);
    await page.mouse.down();
    await page.mouse.move(cx - 220, cy - 80, { steps: 14 });
    await page.mouse.up();
    await settle(page, 1500);
    const afterDrag = await page.evaluate(mapState);
    check(
      run,
      `${tag}: drag pans`,
      Math.abs(afterDrag.center[0] - afterWheel.center[0]) > 0.01,
      `${afterWheel.center} -> ${afterDrag.center}`,
    );
    for (let i = 0; i < 30; i += 1) {
      await page.mouse.wheel(0, 300);
      await page.waitForTimeout(16);
    }
    await settle(page, 2200);
    const rapidOut = await page.evaluate(mapState);
    check(
      run,
      `${tag}: rapid zoom-out respects the minimum zoom`,
      (open.projection === 'globe' ? rapidOut.zoomEq : rapidOut.zoom) >= rapidOut.minZoom - 0.03,
      `zoom ${rapidOut.zoom} (equator ${rapidOut.zoomEq}) vs min ${rapidOut.minZoom}`,
    );
    await snap(page, `${tag}-rapid-out`, run);
    check(
      run,
      `${tag}: markers and layers survive rapid zoom`,
      rapidOut.kubusLayers.length >= 5,
      rapidOut.kubusLayers.join(','),
    );


    run.step = 'selection';
    // Selection continuity + theme switch (phone: selection persists by design).
    const selectedTarget = await selectionContinuity(page, viewport, tag, run);
    await themeSwitchKeepsState(page, tag, run, selectedTarget?.id, scheme);


    await noHorizontalOverflow(page, tag, run);
    if (browserName === 'chromium') {
      // Frame pacing and cover traffic are Chromium measurements: Firefox does
      // not expose cross-origin transfer sizes. Software GL, so relative.
      run.step = 'frames';
      run.frames = await measureFrames(page);
      run.coverTraffic = await coverTraffic(page);
      run.step = 'webgl-loss';
      await webglLossRecovery(page, tag, run);
    }

    const errors = run.console.filter((l) => /^\[(error|pageerror)\]/.test(l));
    // Third-party resource failures are not map faults.
    const mapErrors = errors.filter((l) =>
      /maplibre|webgl|gl context|Cannot read|is not a function|style (is|was) not|image .* could not be loaded/i.test(l),
    );
    check(run, `${tag}: no MapLibre/WebGL errors in console`, mapErrors.length === 0, mapErrors.slice(0, 3).join(' || '));
  } catch (error) {
    run.failed = true;
    run.error = String(error).slice(0, 400);
    await snap(page, `${tag}-error`, run).catch(() => {});
  } finally {
    await browser.close();
  }
}


async function enableSemantics(page) {
  await page.evaluate(() => {
    const el = document.querySelector('flt-semantics-placeholder');
    if (el) el.click();
  });
  await page.waitForTimeout(1200);
}


/** Click what a visitor would click: the centre of a semantics node's painted box. */
async function clickSemantic(page, locator, viewport) {
  const box = await locator.boundingBox();
  if (!box) {
    await locator.dispatchEvent('click');
    return;
  }
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  if (viewport.touch) await page.touchscreen.tap(x, y);
  else await page.mouse.click(x, y);
}

const semanticsText = (page) =>
  page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((n) => (n.getAttribute('aria-label') || n.textContent || '').trim().replace(/\s+/g, ' '))
      .filter(Boolean)
      .join(' | '),
  );

/** Open a marker's entity from the map, press Back, and compare the map state. */
async function entityAndBack(page, viewport, tag, run) {
  await page.evaluate(() => {
    window.__maps[window.__maps.length - 1].jumpTo({ zoom: 15.5, center: [14.5058, 46.0569] });
  });
  await settle(page, 3500);
  const target = await findMarkerTarget(page);
  if (!target) {
    check(run, `${tag}: a marker is available for the entity round trip`, false, 'none rendered');
    return;
  }
  const cameraBefore = await page.evaluate(mapState);
  const pathBefore = new URL(page.url()).pathname;
  await tapAt(page, { x: target.x, y: target.y - 18 }, viewport);
  await settle(page, 2500);
  await snap(page, `${tag}-04-marker-open`, run);
  const labels = await semanticsText(page);
  const view = page.getByRole('button', { name: /View details|Poglej podrobnosti|Podrobnosti/i }).first();
  if ((await view.count()) === 0) {
    run.entityRoundTrip = { opened: false, labels: labels.slice(0, 200) };
    check(run, `${tag}: the marker card offers its entity`, false, labels.slice(0, 200));
    return;
  }
  await clickSemantic(page, view, viewport);
  await settle(page, 4500);
  const pathInEntity = new URL(page.url()).pathname;
  // The entity is a pushed in-app route: the address bar may keep `/map`
  // (route/history hardening is Wave 5C), so "left the map" is read from the
  // map chrome being gone, not from the URL.
  const entityText = await semanticsText(page);
  const mapChrome = /Nearby art and places|Map area|Map tools/i;
  const leftMap = !mapChrome.test(entityText);
  await snap(page, `${tag}-05-entity`, run);
  await page.goBack({ waitUntil: 'domcontentloaded' }).catch(() => {});
  await settle(page, 4500);
  const pathAfter = new URL(page.url()).pathname;
  await snap(page, `${tag}-06-back`, run);
  const mapsAfter = await page.evaluate(() => window.__maps.length);
  const backText = await semanticsText(page);
  const cameraAfter = await page.evaluate(() => {
    const map = window.__maps[window.__maps.length - 1];
    return { zoom: Number(map.getZoom().toFixed(2)), center: [Number(map.getCenter().lng.toFixed(3)), Number(map.getCenter().lat.toFixed(3))] };
  });
  run.entityRoundTrip = { opened: true, pathBefore, pathInEntity, pathAfter, mapsAfter, cameraBefore: { zoom: cameraBefore.zoom, center: cameraBefore.center }, cameraAfter };
  if (viewport.width <= 480) {
    // Phone pushes the entity as a full screen; desktop shows it in the side
    // panel over the same map, so only the camera/instance checks apply there.
    check(run, `${tag}: opening the entity leaves the map screen`, leftMap, entityText.slice(0, 160));
    check(run, `${tag}: Back returns to the map screen`, mapChrome.test(backText), backText.slice(0, 160));
  }
  check(run, `${tag}: Back does not recreate the map`, mapsAfter === 1, `maps=${mapsAfter}`);
  const moved = Math.hypot(cameraAfter.center[0] - cameraBefore.center[0], cameraAfter.center[1] - cameraBefore.center[1]);
  check(
    run,
    `${tag}: Back keeps the camera (not reset to the opening world)`,
    Math.abs(cameraAfter.zoom - cameraBefore.zoom) < 0.6 && moved < 0.02,
    JSON.stringify(run.entityRoundTrip),
  );
}

/** A layout swap (phone <-> wide) recreates the map screen: the state must follow. */
async function layoutSwap(page, viewport, tag, run, words) {
  await page.evaluate(() => {
    window.__maps[window.__maps.length - 1].jumpTo({ zoom: 15.5, center: [14.5058, 46.0569] });
  });
  await settle(page, 3500);
  // A search that still matches the area, so something is left to select.
  const rect = await page.getByRole('textbox').first().boundingBox();
  await page.mouse.click(rect.x + rect.width / 2, rect.y + rect.height / 2);
  await page.waitForTimeout(700);
  await page.keyboard.type('Ljubljana', { delay: 50 });
  await settle(page, 2500);
  await page.mouse.click(viewport.width * 0.6, viewport.height * 0.55);
  await settle(page, 2500);
  const target = await findMarkerTarget(page);
  if (!target) {
    check(run, `${tag}: a marker is available for the layout swap`, false, 'none rendered');
    return;
  }
  await tapAt(page, { x: target.x, y: target.y - 18 }, viewport);
  await settle(page, 2500);
  const before = await page.evaluate(() => {
    const map = window.__maps[window.__maps.length - 1];
    return { zoom: Number(map.getZoom().toFixed(2)), center: [Number(map.getCenter().lng.toFixed(3)), Number(map.getCenter().lat.toFixed(3))], maps: window.__maps.length };
  });
  const selectedBefore = await selectionState(page, target.id);
  await snap(page, `${tag}-07-before-swap`, run);

  // Cross the breakpoint to the phone layout.
  await page.setViewportSize({ width: 390, height: 844 });
  await settle(page, 9000);
  await page.waitForFunction((n) => window.__maps.length > n, before.maps, { timeout: 60000 }).catch(() => {});
  await settle(page, 4000);
  const after = await page.evaluate(() => {
    const map = window.__maps[window.__maps.length - 1];
    return { zoom: Number(map.getZoom().toFixed(2)), center: [Number(map.getCenter().lng.toFixed(3)), Number(map.getCenter().lat.toFixed(3))], maps: window.__maps.length };
  });
  await enableSemantics(page);
  const selectedAfter = await selectionState(page, target.id);
  await snap(page, `${tag}-08-after-swap`, run);
  // The open marker card hides the constraint strip on the phone layout by
  // design; close it (dismissing the selection) to read the strip.
  await clickSemantic(page, page.getByRole('button', { name: /Close/i }).first(), { ...viewport, width: 390, touch: false });
  await settle(page, 2500);
  const text = await semanticsText(page);
  await snap(page, `${tag}-09-after-swap-card-closed`, run);
  run.layoutSwap = { before, after, selectedBefore: selectedBefore.opacityPinsSelection, selectedAfter: selectedAfter.opacityPinsSelection };
  const moved = Math.hypot(after.center[0] - before.center[0], after.center[1] - before.center[1]);
  check(run, `${tag}: the swap recreated the map (a different screen)`, after.maps > before.maps, JSON.stringify({ before: before.maps, after: after.maps }));
  check(run, `${tag}: the new map opens where the old one was`, Math.abs(after.zoom - before.zoom) < 1.2 && moved < 0.05, JSON.stringify({ before, after }));
  check(run, `${tag}: the search text follows the swap`, text.includes(words.queryChip('Ljubljana')), text.slice(0, 220));
  check(run, `${tag}: the selected marker follows the swap`, selectedAfter.opacityPinsSelection, JSON.stringify(selectedAfter));
}

/** Flows that need the Flutter chrome: constraints, filters, entity and Back. */
async function uiScenario(browserName, viewport, scheme, locale, report) {
  viewport = { ...viewport, touch: browserName === 'chromium' && viewport.width <= 480 };
  const browserType = browserName === 'firefox' ? firefox : chromium;
  const browser = await browserType.launch({
    headless: true,
    args:
      browserName === 'chromium'
        ? ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
        : [],
  });
  const sl = locale.startsWith('sl');
  const tag = `${browserName}-${viewport.width}x${viewport.height}-${scheme}-${sl ? 'sl' : 'en'}-ui`;
  const run = { tag, checks: [], screenshots: [], console: [], failed: false };
  report.runs.push(run);
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: 1,
    colorScheme: scheme,
    locale,
    ...(viewport.touch ? { isMobile: true, hasTouch: true } : {}),
  });
  await context.addInitScript(HOOK);
  run.network = await containNetwork(context);
  const page = await context.newPage();
  page.on('pageerror', (e) => run.console.push(`[pageerror] ${e.message.slice(0, 200)}`));
  const words = sl
    ? { search: 'Iskanje: zzqq', reset: /Ponastavi vse/i, area: /Območje zemljevida/i }
    : { search: 'Search: zzqq', reset: /Reset all/i, area: /Map area/i };
  try {
    await page.goto(`${appUrl}${sl ? '/sl' : startPath}`, { waitUntil: 'domcontentloaded' });
    if (sl) {
      // The Slovene launch URL opens the app; go to the map the way a visitor does.
      await page.waitForTimeout(6000);
      await page.goto(`${appUrl}/map`, { waitUntil: 'domcontentloaded' });
    }
    await waitForMap(page);
    await settle(page, browserName === 'firefox' ? 9000 : 6000);
    await enableSemantics(page);
    await page.evaluate(() => {
      window.__maps[window.__maps.length - 1].jumpTo({ zoom: 7, center: [14.99, 46.12] });
    });
    await settle(page, 3500);
    const before = await renderedKubusFeatures(page);
    run.markersBefore = before;
    check(run, `${tag}: markers are on the map before any restriction`, before.dots > 0, JSON.stringify(before));
    check(run, `${tag}: no constraint strip while nothing restricts the map`, !/Reset all|Ponastavi vse/i.test(await semanticsText(page)));
    await snap(page, `${tag}-01-unrestricted`, run);

    // A search restricts the map and says so.
    // Flutter exposes the field as a disabled semantics input; the visitor
    // clicks the painted field, so the script does the same and then types.
    const rect = await page.getByRole('textbox').first().boundingBox();
    if (viewport.touch) await page.touchscreen.tap(rect.x + rect.width / 2, rect.y + rect.height / 2);
    else await page.mouse.click(rect.x + rect.width / 2, rect.y + rect.height / 2);
    await page.waitForTimeout(800);
    await page.keyboard.type('zzqq', { delay: 60 });
    await settle(page, 3000);
    // The results dropdown floats over the strip while it is open, as it does
    // for a visitor; tap the map to dismiss it (the query stays active).
    await snap(page, `${tag}-02a-results-open`, run);
    const tapX = viewport.width <= 480 ? viewport.width / 2 : viewport.width * 0.6;
    const tapY = viewport.height * 0.55;
    if (viewport.touch) await page.touchscreen.tap(tapX, tapY);
    else await page.mouse.click(tapX, tapY);
    await settle(page, 2000);
    const text = await semanticsText(page);
    check(run, `${tag}: the search shows up as a constraint`, text.includes(words.search), text.slice(0, 200));
    check(run, `${tag}: the map-area baseline is listed with it`, words.area.test(text));
    const after = await renderedKubusFeatures(page);
    check(run, `${tag}: the search really removed the markers it claims to`, after.dots === 0, JSON.stringify(after));
    await snap(page, `${tag}-02-search-constraint`, run);

    // Reset all removes every restriction, with no ghost chip.
    await clickSemantic(page, page.getByRole('button', { name: words.reset }).first(), viewport);
    await settle(page, 3000);
    const reset = await semanticsText(page);
    check(run, `${tag}: reset all leaves no constraint chip`, !reset.includes(words.search) && !words.reset.test(reset), reset.slice(0, 160));
    const restored = await renderedKubusFeatures(page);
    check(run, `${tag}: reset all brings the markers back`, restored.dots > 0, JSON.stringify(restored));
    await snap(page, `${tag}-03-after-reset`, run);
    await noHorizontalOverflow(page, tag, run);

    // Map -> entity -> Back: the same map, camera and selection come back.
    if (!sl) await entityAndBack(page, viewport, tag, run);
    if (!sl && viewport.width >= 1024) {
      await layoutSwap(page, viewport, tag, run, { queryChip: (q) => `Search: ${q}` });
    }

    const errors = run.console.filter((l) => /pageerror/.test(l));
    check(run, `${tag}: no uncaught page errors`, errors.length === 0, errors.slice(0, 2).join(' || '));
  } catch (error) {
    run.failed = true;
    run.error = String(error).slice(0, 400);
    await snap(page, `${tag}-error`, run).catch(() => {});
  } finally {
    await browser.close();
  }
}

/** Opening frame at one viewport: renders, nothing overflows, controls reachable. */
async function responsiveScenario(browserName, viewport, scheme, report) {
  const browserType = browserName === 'firefox' ? firefox : chromium;
  const browser = await browserType.launch({
    headless: true,
    args:
      browserName === 'chromium'
        ? ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
        : [],
  });
  const dpr = viewport.dpr || 1;
  const tag = `${browserName}-${viewport.width}x${viewport.height}${dpr > 1 ? `@${dpr}x` : ''}-${scheme}-responsive`;
  const run = { tag, checks: [], screenshots: [], console: [], failed: false };
  report.runs.push(run);
  const touch = browserName === 'chromium' && viewport.width <= 480;
  const context = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    deviceScaleFactor: dpr,
    colorScheme: scheme,
    locale: 'en-US',
    ...(touch ? { isMobile: true, hasTouch: true } : {}),
  });
  await context.addInitScript(HOOK);
  run.network = await containNetwork(context);
  const page = await context.newPage();
  page.on('pageerror', (e) => run.console.push(`[pageerror] ${e.message.slice(0, 200)}`));
  try {
    await page.goto(`${appUrl}${startPath}`, { waitUntil: 'domcontentloaded' });
    await waitForMap(page);
    await settle(page, browserName === 'firefox' ? 9000 : 6000);
    await enableSemantics(page);
    const state = await page.evaluate(mapState);
    run.opening = state;
    check(run, `${tag}: globe fills the shorter side at its minimum zoom`, state.minZoom >= 1 && state.minZoom <= 3.2, `min ${state.minZoom}`);
    await snap(page, `${tag}-01-opening`, run);
    await noHorizontalOverflow(page, tag, run);
    // The primary controls must be on screen and reachable.
    const labels = await semanticsText(page);
    // The compact layout is touch first (pinch zoom, a "Map tools" rail); the
    // zoom buttons belong to the wide layout.
    const controls = [
      ...(viewport.width >= 1024 ? [/Zoom in|Povečaj/i, /Zoom out|Pomanjšaj/i] : []),
      /Center on me|Središči/i,
      /Show filters|Filtri|Filters/i,
    ];
    for (const rx of controls) {
      check(run, `${tag}: control ${rx} is exposed`, rx.test(labels), labels.slice(0, 120));
    }
    // The globe at its minimum zoom (the "world" frame).
    await page.evaluate(() => {
      const map = window.__maps[window.__maps.length - 1];
      map.jumpTo({ zoom: map.getMinZoom(), center: [14.5, 20] });
    });
    await settle(page, 3000);
    await snap(page, `${tag}-02-world`, run);
    check(run, `${tag}: no uncaught page errors`, run.console.length === 0, run.console.slice(0, 2).join(' || '));
  } catch (error) {
    run.failed = true;
    run.error = String(error).slice(0, 400);
    await snap(page, `${tag}-error`, run).catch(() => {});
  } finally {
    await browser.close();
  }
}

await fs.mkdir(outDir, { recursive: true });
const server = await startServer();
const report = { label, startedAt: new Date().toISOString(), runs: [], failed: false };
try {
  if (process.env.QA_FLOW === 'responsive') {
    // 200 % browser zoom at 1440x900 is a 720x450 CSS viewport at 2x density.
    const sizes = [
      ...viewports,
      ...(process.env.QA_ZOOM200 === '0' ? [] : [{ width: 720, height: 450, dpr: 2 }]),
    ];
    for (const browserName of browsers) {
      for (const viewport of sizes) {
        for (const scheme of schemes) {
          await responsiveScenario(browserName, viewport, scheme, report);
        }
      }
    }
  } else if (process.env.QA_FLOW === 'ui') {
    for (const browserName of browsers) {
      for (const viewport of viewports) {
        for (const locale of list('QA_LOCALES', 'en-US')) {
          await uiScenario(browserName, viewport, schemes[0], locale, report);
        }
      }
    }
  } else
  for (const browserName of browsers) {
    for (const viewport of viewports) {
      for (const scheme of schemes) {
        await scenario(browserName, viewport, scheme, report);
      }
      if (process.env.QA_DEGRADED !== '0' && viewport === viewports[0]) {
        const browserType = browserName === 'firefox' ? firefox : chromium;
        const browser = await browserType.launch({
          headless: true,
          args:
            browserName === 'chromium'
              ? ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist']
              : [],
        });
        try {
          await degradedBasemap(browser, browserName, viewport, schemes[0], report);
        } finally {
          await browser.close();
        }
      }
    }
  }
} finally {
  server.close();
}
report.failed = report.runs.some((r) => r.failed);
await fs.writeFile(path.join(outDir, 'report.json'), JSON.stringify(report, null, 2));
for (const run of report.runs) {
  console.log(`\n== ${run.tag} ${run.failed ? 'FAIL' : 'ok'}`);
  for (const c of run.checks) console.log(`  ${c.ok ? 'PASS' : 'FAIL'} ${c.name} ${c.detail ? `(${c.detail})` : ''}`);
  if (run.error) console.log(`  ERROR ${run.error}`);
}
process.exitCode = report.failed ? 1 : 0;
