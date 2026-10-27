/**
 * Request-failure policy for the web runtime smoke's OpenFreeMap traffic.
 *
 * MapLibre cancels in-flight vector-tile fetches when the camera moves or the
 * zoom changes (it aborts the AbortController of tiles that have left the
 * cover). The browser reports those as `net::ERR_ABORTED`. That is a
 * legitimate cancellation, but only while the map still shows content. This
 * module therefore tolerates exactly one class of failure: an aborted
 * OpenFreeMap vector TILE request, and only when the smoke has separately
 * proven that the map shows visible content. Everything else stays fatal:
 * style JSON, sprites, glyphs, TileJSON, other statuses or error texts, and
 * any failure on another host.
 *
 * Pure functions here are unit-tested by ../map_request_policy.test.mjs. The
 * two browser-side helpers are self-contained so Playwright can serialise them.
 */

export const OPENFREEMAP_HOST = 'tiles.openfreemap.org';

/** Chromium's text for a fetch that was cancelled (AbortController, teardown). */
export const CANCELLED_REQUEST_ERROR = 'net::ERR_ABORTED';

// OpenFreeMap planet tiles: /planet/<tileset version>/<z>/<x>/<y>.pbf (or .mvt).
const TILE_PATH = /^\/planet\/[^/]+\/(\d{1,2})\/(\d+)\/(\d+)\.(?:pbf|mvt)$/;
const TILE_RESOURCE_TYPES = new Set(['fetch', 'xhr', 'other']);
const MAX_ZOOM = 22;

/**
 * Classify a URL that the map stack requests from OpenFreeMap.
 * Anything not on the exact host is `foreign`; only a well-formed planet
 * tile path with an in-range z/x/y is `tile`.
 */
export function classifyOpenFreeMapUrl(rawUrl) {
  let url;
  try {
    url = new URL(rawUrl);
  } catch {
    return { kind: 'invalid', host: null };
  }
  if (url.hostname !== OPENFREEMAP_HOST) {
    return { kind: 'foreign', host: url.hostname };
  }
  const host = url.hostname;
  const tile = TILE_PATH.exec(url.pathname);
  if (tile) {
    const z = Number(tile[1]);
    const x = Number(tile[2]);
    const y = Number(tile[3]);
    const span = 2 ** z;
    if (z <= MAX_ZOOM && x < span && y < span) {
      return { kind: 'tile', host, z, x, y };
    }
    return { kind: 'tile-out-of-range', host };
  }
  if (url.pathname.startsWith('/fonts/')) return { kind: 'glyphs', host };
  if (url.pathname.startsWith('/sprite')) return { kind: 'sprite', host };
  if (/^\/planet\/?$/.test(url.pathname)) return { kind: 'tilejson', host };
  if (url.pathname.startsWith('/styles/') || url.pathname.endsWith('.json')) {
    return { kind: 'style', host };
  }
  return { kind: 'other', host };
}

/**
 * Decide whether one failed request may be tolerated.
 * Returns `{ tolerable: true, ... }` only for an aborted GET of an OpenFreeMap
 * vector tile with a fetch-like resource type. The caller must still require
 * visible map content (see evaluateRequestFailures).
 */
export function classifyRequestFailure(failure) {
  const info = classifyOpenFreeMapUrl(failure?.url);
  const fail = (reason) => ({ tolerable: false, reason, kind: info.kind });

  if (info.kind !== 'tile') {
    return fail(info.kind === 'foreign' ? `failure on other host ${info.host}` : `not a tile request (${info.kind})`);
  }
  if (failure.method && failure.method.toUpperCase() !== 'GET') {
    return fail(`tile request method ${failure.method}`);
  }
  if (failure.errorText !== CANCELLED_REQUEST_ERROR) {
    return fail(`tile failed with ${failure.errorText || 'no error text'}, not a cancellation`);
  }
  if (failure.resourceType && !TILE_RESOURCE_TYPES.has(failure.resourceType)) {
    return fail(`tile request resource type ${failure.resourceType}`);
  }
  return {
    tolerable: true,
    reason: 'MapLibre tile cancelled by the browser',
    kind: 'tile',
    z: info.z,
    x: info.x,
    y: info.y,
  };
}

/**
 * Judge a tile response that came back with an HTTP error status. These are
 * never tolerated; the smoke's httpErrors check also fails on them.
 */
export function classifyTileResponse(response) {
  const info = classifyOpenFreeMapUrl(response?.url);
  if (info.kind !== 'tile') {
    return { tolerable: false, reason: `not a tile response (${info.kind})` };
  }
  if (response.status >= 400) {
    return { tolerable: false, reason: `tile HTTP ${response.status}` };
  }
  return { tolerable: true, reason: 'tile response ok' };
}

/**
 * Turn the browser-side map probe into a verdict. Only the most recently
 * created MapLibre map whose container is still attached is judged, because
 * that is the map the user sees.
 */
export function assessMapContentSnapshot(snapshot) {
  if (!snapshot || !Array.isArray(snapshot.maps)) {
    return { visible: false, reasons: ['no MapLibre probe data'] };
  }
  const live = snapshot.maps.filter((map) => map.containerConnected && !map.removed);
  if (live.length === 0) {
    return { visible: false, reasons: ['no attached MapLibre map'] };
  }
  const map = live[live.length - 1];
  const reasons = [];
  if (!map.styleLoaded) reasons.push('style not loaded');
  if (!map.tilesLoaded) reasons.push('tiles for the final viewport not loaded');
  if (!(map.renderedFeatures > 0)) reasons.push('no rendered features in the viewport');
  if (!map.canvas || !(map.canvas.w > 0) || !(map.canvas.h > 0)) reasons.push('map canvas is empty');
  return {
    visible: reasons.length === 0,
    reasons,
    map: { id: map.id, zoom: map.zoom, renderedFeatures: map.renderedFeatures },
  };
}

/**
 * Apply the policy to every failed request the smoke recorded.
 *
 * - `failures`: requestfailed records `{ url, method, resourceType, errorText }`.
 * - `mapContent`: the assessMapContentSnapshot() result taken before teardown,
 *   or null when none was taken.
 *
 * Tolerated tile cancellations count only when the map content check passed.
 * Otherwise they move to `fatal`, so a cancelled tile can never pass unseen.
 */
export function evaluateRequestFailures({ failures = [], mapContent = null } = {}) {
  const fatal = [];
  const tolerated = [];
  for (const failure of failures) {
    const verdict = classifyRequestFailure(failure);
    const entry = { url: failure.url, errorText: failure.errorText, ...verdict };
    if (verdict.tolerable) {
      tolerated.push(entry);
    } else {
      fatal.push(entry);
    }
  }

  const contentVerdict = mapContent
    ? assessMapContentSnapshot(mapContent)
    : { visible: false, reasons: ['map content was not checked'] };

  if (tolerated.length > 0 && !contentVerdict.visible) {
    for (const entry of tolerated) {
      fatal.push({
        ...entry,
        tolerable: false,
        reason: `tile cancelled but map content not visible: ${contentVerdict.reasons.join('; ')}`,
      });
    }
    tolerated.length = 0;
  }

  return {
    ok: fatal.length === 0,
    fatal,
    tolerated,
    contentChecked: mapContent !== null,
    contentVerdict,
  };
}

/** Human-readable line for a smoke error message or artifact. */
export function describeFailure(entry) {
  const line = `${entry.method || 'GET'} ${entry.url} ${entry.errorText || ''}`.trim();
  return entry.reason ? `${line} [${entry.reason}]` : line;
}

/**
 * Browser-side probe, injected with addInitScript before the app loads.
 * The UMD MapLibre bundle creates `globalThis.maplibregl = {}` and then
 * assigns `.Map` onto it, so the hook is an accessor on that object. Each
 * constructed map is recorded so the smoke can judge what is on screen. No
 * app code is touched and the map behaves as before.
 */
export const MAP_CONTENT_PROBE_INIT = `
(() => {
  const maps = [];
  Object.defineProperty(window, '__kubusQaMaps', { value: maps, configurable: false });
  const wrapMapClass = (Original) => {
    if (typeof Original !== 'function') return Original;
    function QaMap(options) {
      const map = new Original(options);
      // Stacked wrappers (globe atmosphere, WebGL handler) return the same map
      // object through each layer, so register it once.
      if (!maps.includes(map)) {
        map.__kubusQaId = maps.length + 1;
        maps.push(map);
      }
      return map;
    }
    QaMap.prototype = Original.prototype;
    Object.setPrototypeOf(QaMap, Original);
    for (const key of Object.keys(Original)) {
      try { QaMap[key] = Original[key]; } catch (_) {}
    }
    return QaMap;
  };
  const hookRuntime = (runtime) => {
    if (!runtime || typeof runtime !== 'object') return;
    let wrapped;
    Object.defineProperty(runtime, 'Map', {
      configurable: true,
      enumerable: true,
      get() { return wrapped; },
      set(value) { wrapped = wrapMapClass(value); },
    });
  };
  let current;
  Object.defineProperty(window, 'maplibregl', {
    configurable: true,
    enumerable: true,
    get() { return current; },
    set(value) { current = value; hookRuntime(value); },
  });
})();
`;

/**
 * Browser-side snapshot of the live map. Self-contained on purpose: it is
 * passed to page.evaluate() as a function and must not close over imports.
 */
export function readMapContentSnapshotInPage() {
  const maps = (window.__kubusQaMaps || []).map((map) => {
    const container = map.getContainer ? map.getContainer() : null;
    const canvas = map.getCanvas ? map.getCanvas() : null;
    let renderedFeatures = 0;
    try {
      renderedFeatures = map.queryRenderedFeatures().length;
    } catch (_) {}
    return {
      id: map.__kubusQaId,
      containerConnected: Boolean(container && container.isConnected),
      removed: Boolean(map._removed),
      zoom: map.getZoom(),
      styleLoaded: map.isStyleLoaded(),
      tilesLoaded: map.areTilesLoaded(),
      renderedFeatures,
      canvas: canvas ? { w: canvas.width, h: canvas.height } : null,
    };
  });
  return { href: location.href, maps };
}
