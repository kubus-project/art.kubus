// Map continuity probe: what the marker source, the cover pipeline and the
// frame clock do while the camera crosses the cluster -> marker threshold.
//
// Serves a prebuilt Flutter web bundle. Public GET reads reach the production
// API so the map shows real markers and covers; every write and analytics call
// is answered locally, so nothing is created and no telemetry is sent.
//
//   QA_WEB_ROOT=build/web QA_LABEL=after node scripts/qa/map_continuity_probe.mjs
//
// Env: QA_VIEWPORT=1440x900   QA_SCHEME=light|dark   QA_GL=hardware|swiftshader
//      QA_CENTER=14.5058,46.0519 (lng,lat)   QA_PORT=8132
//      QA_WARM=1 runs the scenario a second time in the same browser context
//      (HTTP cache and service state warm) and reports it as a separate pass.
//      QA_BROWSER=chromium|firefox
//
// Per phase it records every `kubus_markers` setData (feature, cluster and
// marker counts, ids added/removed, whether the write only carried transient
// entry-animation values), every cover image registered with the map, media
// requests (count, duplicates, failures), and requestAnimationFrame intervals.
// Output: output/playwright/artifacts/map-continuity/<label>/report.json (+ screenshots).
// Absolute frame timings depend on the machine; compare builds on one machine
// in one session, and read the counts as the architecture-level result.
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium, firefox } from 'playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/web');
const label = (process.env.QA_LABEL || 'probe').trim();
const outDir = path.resolve(rootDir, 'output/playwright/artifacts/map-continuity', label);
const port = Number(process.env.QA_PORT || 8132);
const appUrl = `http://127.0.0.1:${port}`;
const scheme = process.env.QA_SCHEME || 'light';
const glMode = process.env.QA_GL || 'hardware';
const browserName = process.env.QA_BROWSER || 'chromium';
const warm = process.env.QA_WARM === '1';
const [lng, lat] = (process.env.QA_CENTER || '14.5058,46.0519').split(',').map(Number);
const [vw, vh] = (process.env.QA_VIEWPORT || '1440x900').split('x').map(Number);

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
  '.pbf': 'application/x-protobuf',
};

function startServer() {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, appUrl);
    let rel = decodeURIComponent(url.pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(webRoot, rel);
    if (path.relative(webRoot, file).startsWith('..')) return res.writeHead(403).end();
    try {
      if ((await fs.stat(file)).isDirectory()) file = path.join(file, 'index.html');
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

async function installNetworkPolicy(page) {
  if (page.routeWebSocket) {
    await page.routeWebSocket(/^wss:\/\/api\.kubus\.site\//, (ws) => {
      ws.onMessage((message) => {
        const text = message.toString();
        if (text === '2') ws.send('3');
        else if (text.startsWith('40')) ws.send('40{"sid":"qa-socket"}');
      });
      ws.send('0{"sid":"qa","upgrades":[],"pingInterval":25000,"pingTimeout":20000,"maxPayload":1000000}');
    });
  }
  await page.route(/^https:\/\/(?:api|bapi)\.kubus\.site\//, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    const cors = {
      'access-control-allow-origin': appUrl,
      'access-control-allow-credentials': 'true',
      'access-control-allow-headers': '*',
      'access-control-allow-methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    };
    if (request.method() !== 'GET' || /\/api\/(analytics|diagnostics|telemetry)/.test(url.pathname)) {
      await route.fulfill({ status: 204, headers: cors, body: '' });
      return;
    }
    try {
      const headers = { ...request.headers() };
      delete headers.origin;
      delete headers.referer;
      const response = await route.fetch({ timeout: 20000, headers });
      await route.fulfill({ response, headers: { ...response.headers(), ...cors } });
    } catch {
      await route.fulfill({ status: 503, headers: cors, body: '' });
    }
  });
}

// Runs in the page before any app script.
const HOOK = () => {
  const probe = {
    maps: [],
    phase: 'boot',
    writes: [],
    images: [],
    frames: [],
    longTasks: [],
    lastIds: null,
  };
  window.__probe = probe;
  // Opt in to the app's cover-pipeline timings (kubus_cover_perf_probe.dart).
  const coverPerf = [];
  coverPerf.push = function (entry) {
    entry.t = performance.now();
    entry.probePhase = probe.phase;
    return Array.prototype.push.call(this, entry);
  };
  window.__kubusCoverPerf = coverPerf;
  window.queryMarkers = (m) => {
    try {
      const layers = (m.getStyle()?.layers || []).filter((l) => l.source === 'kubus_markers').map((l) => l.id);
      return m.queryRenderedFeatures({ layers });
    } catch {
      return [];
    }
  };
  const now = () => performance.now();

  const frame = (() => {
    let last = 0;
    const tick = (t) => {
      if (last) probe.frames.push([probe.phase, t - last]);
      last = t;
      requestAnimationFrame(tick);
    };
    return () => requestAnimationFrame(tick);
  })();
  frame();
  try {
    new PerformanceObserver((list) => {
      for (const entry of list.getEntries()) {
        probe.longTasks.push([probe.phase, entry.duration, entry.startTime]);
      }
    }).observe({ type: 'longtask', buffered: true });
  } catch {
    /* Firefox has no longtask entries */
  }

  const hookSource = (map) => {
    const source = map.getSource && map.getSource('kubus_markers');
    if (!source) return false;
    const proto = Object.getPrototypeOf(source);
    if (proto.__probeHooked) return true;
    proto.__probeHooked = true;
    const setData = proto.setData;
    proto.setData = function (data, ...rest) {
      if (this.id === 'kubus_markers' && data && Array.isArray(data.features)) {
        const ids = new Set();
        let clusters = 0;
        let markers = 0;
        let animating = 0;
        let covers = 0;
        for (const f of data.features) {
          const p = f.properties || {};
          const id = String(p.id ?? f.id ?? '');
          ids.add(id);
          if (p.kind === 'cluster') clusters += 1;
          else markers += 1;
          const op = typeof p.entryOpacity === 'number' ? p.entryOpacity : 1;
          const sc = typeof p.entryScale === 'number' ? p.entryScale : 1;
          if (op < 0.999 || Math.abs(sc - 1) > 0.001) animating += 1;
          if (typeof p.icon === 'string' && p.icon.startsWith('mc_')) covers += 1;
        }
        let added = 0;
        let removed = 0;
        if (probe.lastIds) {
          for (const id of ids) if (!probe.lastIds.has(id)) added += 1;
          for (const id of probe.lastIds) if (!ids.has(id)) removed += 1;
        } else {
          added = ids.size;
        }
        probe.lastIds = ids;
        const started = now();
        const result = setData.call(this, data, ...rest);
        const callMs = now() - started;
        const m = probe.maps[probe.maps.length - 1];
        probe.writes.push({
          phase: probe.phase,
          t: now(),
          zoom: m ? m.getZoom() : null,
          features: data.features.length,
          clusters,
          markers,
          animating,
          covers,
          added,
          removed,
          callMs,
        });
        return result;
      }
      return setData.call(this, data, ...rest);
    };
    return true;
  };

  const timer = setInterval(() => {
    const proto = window.maplibregl && window.maplibregl.Map && window.maplibregl.Map.prototype;
    if (proto && !proto.__probeHooked) {
      proto.__probeHooked = true;
      const setStyle = proto.setStyle;
      proto.setStyle = function (...args) {
        if (!probe.maps.includes(this)) probe.maps.push(this);
        return setStyle.apply(this, args);
      };
      const addImage = proto.addImage;
      proto.addImage = function (id, ...args) {
        probe.images.push({ phase: probe.phase, t: now(), id: String(id) });
        return addImage.call(this, id, ...args);
      };
    }
    const m = probe.maps[probe.maps.length - 1];
    if (m && hookSource(m)) clearInterval(timer);
  }, 2);
};

function quantile(values, q) {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return Number(sorted[Math.min(sorted.length - 1, Math.floor(q * sorted.length))].toFixed(1));
}

function summarize(raw, media, phases) {
  const out = {};
  for (const phase of phases) {
    const writes = raw.writes.filter((w) => w.phase === phase);
    const frames = raw.frames.filter(([p]) => p === phase).map(([, d]) => d);
    const longTasks = raw.longTasks.filter(([p]) => p === phase).map(([, d]) => d);
    // Where the longest task sat: the zoom of the marker write nearest to it.
    const worst = raw.longTasks.filter(([p]) => p === phase).sort((a, b) => b[1] - a[1])[0];
    const nearWrite = worst
      ? raw.writes.reduce((best, w) => (!best || Math.abs(w.t - worst[2]) < Math.abs(best.t - worst[2]) ? w : best), null)
      : null;
    let rapid = 0;
    for (let i = 1; i < writes.length; i += 1) {
      if (writes[i].t - writes[i - 1].t < 60) rapid += 1;
    }
    const topology = [];
    for (let i = 0; i < writes.length; i += 1) {
      const w = writes[i];
      const prev = i ? writes[i - 1] : null;
      if (!prev || prev.clusters !== w.clusters || w.added + w.removed > 0) {
        topology.push({
          zoom: w.zoom && Number(w.zoom.toFixed(2)),
          clusters: w.clusters,
          markers: w.markers,
          added: w.added,
          removed: w.removed,
        });
      }
    }
    const images = raw.images.filter((i) => i.phase === phase);
    const phaseMedia = media.filter((m) => m.phase === phase);
    const urls = phaseMedia.map((m) => m.url);
    out[phase] = {
      writes: writes.length,
      rapidWrites: rapid,
      animationOnlyWrites: writes.filter((w) => w.animating > 0 && w.added + w.removed === 0).length,
      maxAddedInOneWrite: writes.reduce((m, w) => Math.max(m, w.added), 0),
      maxRemovedInOneWrite: writes.reduce((m, w) => Math.max(m, w.removed), 0),
      topologyChanges: topology.length,
      topology: topology.slice(0, 40),
      frames: frames.length,
      frameP50: quantile(frames, 0.5),
      frameP95: quantile(frames, 0.95),
      frameP99: quantile(frames, 0.99),
      frameMax: frames.length ? Number(Math.max(...frames).toFixed(1)) : null,
      framesOver50: frames.filter((d) => d > 50).length,
      framesOver100: frames.filter((d) => d > 100).length,
      longTasks: longTasks.length,
      longTaskMax: longTasks.length ? Number(Math.max(...longTasks).toFixed(1)) : null,
      longTaskNearWrite: nearWrite
        ? { zoom: Number(nearWrite.zoom.toFixed(2)), dtMs: Math.round(nearWrite.t - worst[2]), added: nearWrite.added, features: nearWrite.features }
        : null,
      coverImagesAdded: images.filter((i) => i.id.startsWith('mc_')).length,
      otherImagesAdded: images.filter((i) => !i.id.startsWith('mc_')).length,
      otherImageIds: images.filter((i) => !i.id.startsWith('mc_')).map((i) => i.id).slice(0, 16),
      mediaRequests: urls.length,
      mediaDuplicates: urls.length - new Set(urls).size,
      mediaFailed: phaseMedia.filter((m) => m.failed).length,
      mediaDuplicateUrls: [...new Set(urls.filter((u, i) => urls.indexOf(u) !== i))].slice(0, 8),
      mediaFailedUrls: phaseMedia.filter((m) => m.failed).map((m) => m.url).slice(0, 8),
    };
  }
  return out;
}

const isMedia = (url, type) => {
  if (/\/tiles?\/|\.pbf|glyphs|sprite|fonts?\//i.test(url)) return false;
  if (url.startsWith(appUrl)) return false;
  return type === 'image' || /\.(jpe?g|png|webp|avif|gif)(\?|$)|\/media\/|\/uploads\/|\/ipfs\//i.test(url);
};

const launchArgs =
  browserName !== 'chromium'
    ? []
    : glMode === 'hardware'
      ? ['--use-angle=d3d11', '--ignore-gpu-blocklist', '--enable-gpu-rasterization']
      : ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'];

const server = await startServer();
await fs.mkdir(outDir, { recursive: true });
const engine = browserName === 'firefox' ? firefox : chromium;
const browser = await engine.launch({ headless: true, args: launchArgs });
const report = { label, webRoot, glMode, scheme, browser: browserName, viewport: `${vw}x${vh}`, passes: [] };

async function runPass(context, passName) {
  const page = await context.newPage();
  await installNetworkPolicy(page);
  const media = [];
  const byRequest = new Map();
  const currentPhase = { value: 'boot' };
  page.on('request', (request) => {
    const url = request.url();
    if (!isMedia(url, request.resourceType())) return;
    const entry = { phase: currentPhase.value, url, failed: false, t: Date.now() };
    byRequest.set(request, entry);
    media.push(entry);
  });
  page.on('requestfailed', (request) => {
    const entry = byRequest.get(request);
    if (entry) entry.failed = true;
  });
  page.on('response', (response) => {
    const entry = byRequest.get(response.request());
    if (entry && response.status() >= 400) entry.failed = true;
  });

  const t0 = Date.now();
  await page.goto(`${appUrl}/map`, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(
    () => {
      const p = window.__probe;
      const m = p && p.maps[p.maps.length - 1];
      return !!m && (m.getStyle()?.layers || []).some((l) => l.id.startsWith('kubus_'));
    },
    null,
    { timeout: 120000 },
  );
  const setPhase = async (name) => {
    currentPhase.value = name;
    await page.evaluate((n) => {
      window.__probe.phase = n;
    }, name);
  };
  const camera = (options, waitMs) =>
    page.evaluate(
      ({ options, waitMs }) =>
        new Promise((resolve) => {
          const p = window.__probe;
          const m = p.maps[p.maps.length - 1];
          if (options.jump) m.jumpTo(options.jump);
          else m.easeTo({ ...options, essential: true });
          setTimeout(resolve, waitMs);
        }),
      { options, waitMs },
    );

  // Cold entry at the city, just below the threshold.
  // The app runs its own initial camera; let it finish before positioning.
  await setPhase('cold');
  const firstMarkers = await page
    .waitForFunction(() => window.__probe.writes.some((w) => w.features > 0), null, { timeout: 60000 })
    .then(() => Date.now() - t0)
    .catch(() => null);
  await page.waitForTimeout(6000);
  await setPhase('approach');
  await camera({ jump: { center: [lng, lat], zoom: 11.4 } }, 6000);
  await page.screenshot({ path: path.join(outDir, `${passName}-cold-z11.4.png`) });

  // Slow zoom across the threshold (11.4 -> 13.4 over 5 s).
  await setPhase('slowZoomIn');
  const coverTrack = [];
  const coverStart = Date.now();
  const sample = async () =>
    page.evaluate(() => {
      const p = window.__probe;
      const m = p.maps[p.maps.length - 1];
      const feats = queryMarkers(m);
      const seen = new Map();
      for (const f of feats) {
        const id = String(f.properties?.id ?? '');
        if (!seen.has(id)) seen.set(id, f.properties || {});
      }
      const markers = [...seen.values()].filter((pr) => pr.kind !== 'cluster');
      return {
        zoom: Number(m.getZoom().toFixed(2)),
        visibleMarkers: markers.length,
        visibleCovers: markers.filter((pr) => String(pr.icon || '').startsWith('mc_')).length,
      };
    });
  const tracker = (async () => {
    while (Date.now() - coverStart < 16000) {
      coverTrack.push({ ms: Date.now() - coverStart, ...(await sample()) });
      await page.waitForTimeout(250);
    }
  })();
  await camera({ zoom: 13.4, duration: 5000 }, 5200);
  await setPhase('settleClose');
  await page.screenshot({ path: path.join(outDir, `${passName}-z13.4-moving-end.png`) });
  await tracker;
  await page.screenshot({ path: path.join(outDir, `${passName}-z13.4-settled.png`) });

  // Zoom back out across the threshold.
  await setPhase('zoomOut');
  await camera({ zoom: 11.4, duration: 3000 }, 4500);

  // Fast zoom in.
  await setPhase('fastZoomIn');
  await camera({ zoom: 14, duration: 700 }, 4000);

  // Pan at street scale.
  await setPhase('pan');
  for (const [dx, dy] of [[300, 0], [0, 220], [-300, 0], [0, -220], [260, 160]]) {
    await page.evaluate(
      ({ dx, dy }) =>
        new Promise((resolve) => {
          const p = window.__probe;
          const m = p.maps[p.maps.length - 1];
          m.panBy([dx, dy], { duration: 450 });
          setTimeout(resolve, 650);
        }),
      { dx, dy },
    );
  }
  await page.waitForTimeout(2500);

  // Camera jitter around the threshold (trackpad settling).
  await setPhase('thresholdJitter');
  await camera({ jump: { center: [lng, lat], zoom: 12.3 } }, 2500);
  const jitterStart = await page.evaluate(() => window.__probe.writes.length);
  for (let i = 0; i < 12; i += 1) {
    await camera({ jump: { zoom: i % 2 ? 12.06 : 11.94 } }, 160);
  }
  await page.waitForTimeout(2500);
  const jitterWrites = await page.evaluate(
    (start) => window.__probe.writes.slice(start).map((w) => [Number(w.zoom.toFixed(2)), w.clusters, w.markers]),
    jitterStart,
  );

  // Select a marker at street scale, then cross the threshold with it selected.
  await setPhase('select');
  await camera({ jump: { center: [lng, lat], zoom: 13.4 } }, 3500);
  const findTarget = () => page.evaluate(() => {
    const p = window.__probe;
    const m = p.maps[p.maps.length - 1];
    const canvas = m.getCanvas().getBoundingClientRect();

    // Source features, not rendered ones: rendered-feature queries can throw
    // inside MapLibre's symbol index while labels are being placed.
    const feats = m
      .querySourceFeatures('kubus_markers')
      .filter((f) => f.properties?.kind === 'marker' && Number(f.properties?.entryOpacity ?? 1) > 0.9);
    const centre = m.project(m.getCenter());
    feats.sort((a, b) => {
      const pa = m.project(a.geometry.coordinates);
      const pb = m.project(b.geometry.coordinates);
      return Math.hypot(pa.x - centre.x, pa.y - centre.y) - Math.hypot(pb.x - centre.x, pb.y - centre.y);
    });
    const f = feats[0];
    if (!f) return null;
    const pt = m.project(f.geometry.coordinates);
    return { id: String(f.properties.id), x: canvas.left + pt.x, y: canvas.top + pt.y - 6 };
  });
  let target = await findTarget();
  for (let i = 0; !target && i < 10; i += 1) {
    await page.waitForTimeout(500);
    target = await findTarget();
  }
  let selection = null;
  if (target) {
    await page.mouse.click(target.x, target.y);
    // Card opening sequence: what the first frames after the tap show.
    const openedAt = Date.now();
    for (let i = 0; i < 6; i += 1) {
      await page.screenshot({ path: path.join(outDir, `${passName}-card-open-${i}-${Date.now() - openedAt}ms.png`) });
    }
    await page.waitForTimeout(1200);
    await page.screenshot({ path: path.join(outDir, `${passName}-selected.png`) });
    // Selection is checked through what the visitor sees: the selected
    // marker stays in the source (pinned out of clusters) and the quick card
    // stays open. The map's own zoom buttons are used, because they move the
    // camera programmatically; a user drag or wheel closes the card by design.
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(800);
    const state = () =>
      page.evaluate((id) => {
        const m = window.__probe.maps[window.__probe.maps.length - 1];
        const labels = [...document.querySelectorAll('flt-semantics')]
          .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim());
        return {
          zoom: Number(m.getZoom().toFixed(2)),
          inSource: m.querySourceFeatures('kubus_markers').some((f) => String(f.properties?.id) === id),
          card: labels.some((t) => /view details/i.test(t)),
        };
      }, target.id);
    const zoomButton = async (name) => {
      const button = page.getByRole('button', { name, exact: true }).first();
      const box = await button.boundingBox({ timeout: 3000 }).catch(() => null);
      if (!box) return false;
      await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
      return true;
    };
    // The click can land on a neighbour: the selected id is the one the
    // marker layers' selection expressions name.
    const selectedId = await page.evaluate(() => {
      const m = window.__probe.maps[window.__probe.maps.length - 1];
      const layers = (m.getStyle()?.layers || []).filter((l) => l.source === 'kubus_markers');
      const text = JSON.stringify(layers.map((l) => [l.layout, l.paint]));
      const ids = text.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g) || [];
      return ids[0] || null;
    });
    if (selectedId) target.id = selectedId;
    const checks = [];
    checks.push({ step: 'selected', selectedId, ...(await state()) });
    await setPhase('selectedZoomOut');
    for (const step of ['Zoom out', 'Zoom out', 'Zoom in', 'Zoom in']) {
      const clicked = await zoomButton(step);
      await page.waitForTimeout(1600);
      checks.push({ step, clicked, ...(await state()) });
      if (step === 'Zoom out' && checks.length === 3) {
        await page.screenshot({ path: path.join(outDir, `${passName}-selected-zoomed-out.png`) });
      }
    }
    await page.screenshot({ path: path.join(outDir, `${passName}-selected-after.png`) });
    selection = { id: target.id, checks };
  }

  const raw = await page.evaluate(() => {
    const p = window.__probe;
    return { writes: p.writes, images: p.images, frames: p.frames, longTasks: p.longTasks, coverPerf: window.__kubusCoverPerf || [] };
  });
  const phases = [...new Set(raw.writes.map((w) => w.phase).concat(raw.frames.map(([p]) => p)))];
  const coverMedia = media.filter((m) => !/\/avatars?\//i.test(m.url));
  const firstCover = raw.images.find((i) => i.id.startsWith('mc_'));
  await page.close();
  return {
    pass: passName,
    msToFirstMarkerWrite: firstMarkers,
    msFirstCoverRegisteredAfterNav: firstCover ? Math.round(firstCover.t) : null,
    totals: {
      writes: raw.writes.length,
      coverImages: raw.images.filter((i) => i.id.startsWith('mc_')).length,
      mediaRequests: coverMedia.length,
      mediaDuplicates: coverMedia.length - new Set(coverMedia.map((m) => m.url)).size,
      mediaFailed: coverMedia.filter((m) => m.failed).length,
    },
    phases: summarize(raw, coverMedia, phases),
    coverPhases: Object.fromEntries(
      [...new Set(raw.coverPerf.map((e) => e.phase))].map((name) => {
        const ms = raw.coverPerf.filter((e) => e.phase === name).map((e) => e.ms);
        return [name, { n: ms.length, p50: quantile(ms, 0.5), p95: quantile(ms, 0.95), total: Math.round(ms.reduce((a, b) => a + b, 0)) }];
      }),
    ),
    coverEventsByPhase: raw.coverPerf.reduce((acc, e) => {
      const key = `${e.probePhase}:${e.phase}`;
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {}),
    slowestSetData: raw.writes.reduce((m, w) => (w.callMs > (m?.callMs ?? -1) ? w : m), null),
    coverTrack,
    jitterWrites,
    selection,
  };
}

try {
  const context = await browser.newContext({
    viewport: { width: vw, height: vh },
    deviceScaleFactor: 1,
    colorScheme: scheme,
    locale: 'en-US',
    hasTouch: browserName === 'chromium' && vw <= 480,
  });
  await context.addInitScript(() => {
    const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
    set('has_completed_onboarding', 'true');
    set('has_seen_welcome', 'true');
    set('is_first_launch', 'false');
    set('skipOnboardingForReturningUsers', 'true');
    set('map_onboarding_mobile_seen_v2', 'true');
    set('map_onboarding_desktop_seen_v2', 'true');
    set('selected_language', JSON.stringify('en'));
  });
  await context.addInitScript(HOOK);
  report.passes.push(await runPass(context, 'cold'));
  if (warm) report.passes.push(await runPass(context, 'warm'));
  await context.close();
} finally {
  await browser.close();
  server.close();
}
await fs.writeFile(path.join(outDir, 'report.json'), JSON.stringify(report, null, 1));
for (const pass of report.passes) {
  console.log(`== ${pass.pass}: first marker write ${pass.msToFirstMarkerWrite} ms, totals ${JSON.stringify(pass.totals)}`);
  for (const [phase, s] of Object.entries(pass.phases)) {
    console.log(
      `${phase.padEnd(16)} writes ${s.writes} rapid ${s.rapidWrites} animOnly ${s.animationOnlyWrites} ` +
        `maxAdd ${s.maxAddedInOneWrite} maxRem ${s.maxRemovedInOneWrite} topo ${s.topologyChanges} | ` +
        `frames p50 ${s.frameP50} p95 ${s.frameP95} p99 ${s.frameP99} max ${s.frameMax} >100 ${s.framesOver100} | ` +
        `covers ${s.coverImagesAdded} media ${s.mediaRequests} dup ${s.mediaDuplicates} fail ${s.mediaFailed}`,
    );
  }
  console.log('selection', JSON.stringify(pass.selection));
  console.log('jitter', JSON.stringify(pass.jitterWrites));
}
