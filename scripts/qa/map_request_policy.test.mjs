import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  MAP_CONTENT_PROBE_INIT,
  assessMapContentSnapshot,
  classifyOpenFreeMapUrl,
  classifyRequestFailure,
  classifyTileResponse,
  evaluateRequestFailures,
} from './lib/map_request_policy.mjs';

const TILESET = 'https://tiles.openfreemap.org/planet/20261025_080012_pt';

const visibleMap = {
  maps: [
    {
      id: 3,
      containerConnected: true,
      removed: false,
      zoom: 1.921,
      styleLoaded: true,
      tilesLoaded: true,
      renderedFeatures: 45,
      canvas: { w: 1170, h: 1992 },
    },
  ],
};

const abortedFailure = (overrides = {}) => ({
  url: `${TILESET}/2/0/0.pbf`,
  method: 'GET',
  resourceType: 'fetch',
  errorText: 'net::ERR_ABORTED',
  ...overrides,
});

test('an aborted OpenFreeMap vector tile is tolerated when the map content is visible', () => {
  const result = evaluateRequestFailures({
    failures: [abortedFailure()],
    mapContent: visibleMap,
  });

  assert.equal(result.ok, true);
  assert.equal(result.fatal.length, 0);
  assert.equal(result.tolerated.length, 1);
  assert.equal(result.tolerated[0].kind, 'tile');
  assert.deepEqual(
    { z: result.tolerated[0].z, x: result.tolerated[0].x, y: result.tolerated[0].y },
    { z: 2, x: 0, y: 0 },
  );
  assert.equal(result.contentChecked, true);
});

test('a tile .mvt path is classified as a tile as well', () => {
  const verdict = classifyRequestFailure(abortedFailure({ url: `${TILESET}/3/4/5.mvt` }));
  assert.equal(verdict.tolerable, true);
  assert.equal(verdict.z, 3);
});

test('an aborted tile fails when no map content was checked', () => {
  const result = evaluateRequestFailures({ failures: [abortedFailure()], mapContent: null });

  assert.equal(result.ok, false);
  assert.equal(result.tolerated.length, 0);
  assert.equal(result.fatal.length, 1);
  assert.match(result.fatal[0].reason, /map content not visible/);
});

test('an aborted tile fails when the map shows no visible content', () => {
  const cases = [
    { name: 'no map at all', snapshot: { maps: [] }, expect: 'no attached MapLibre map' },
    {
      name: 'detached map container',
      snapshot: { maps: [{ ...visibleMap.maps[0], containerConnected: false }] },
      expect: 'no attached MapLibre map',
    },
    {
      name: 'style still loading',
      snapshot: { maps: [{ ...visibleMap.maps[0], styleLoaded: false }] },
      expect: 'style not loaded',
    },
    {
      name: 'viewport tiles not loaded',
      snapshot: { maps: [{ ...visibleMap.maps[0], tilesLoaded: false }] },
      expect: 'tiles for the final viewport not loaded',
    },
    {
      name: 'nothing rendered',
      snapshot: { maps: [{ ...visibleMap.maps[0], renderedFeatures: 0 }] },
      expect: 'no rendered features in the viewport',
    },
    {
      name: 'blank canvas',
      snapshot: { maps: [{ ...visibleMap.maps[0], canvas: { w: 0, h: 0 } }] },
      expect: 'map canvas is empty',
    },
  ];

  for (const { name, snapshot, expect } of cases) {
    const result = evaluateRequestFailures({ failures: [abortedFailure()], mapContent: snapshot });
    assert.equal(result.ok, false, name);
    assert.equal(result.fatal.length, 1, name);
    assert.match(result.fatal[0].reason, new RegExp(expect), name);
  }
});

test('an aborted style JSON, sprite, glyph or TileJSON request stays fatal', () => {
  const critical = [
    { name: 'style JSON', url: 'https://tiles.openfreemap.org/styles/liberty.json' },
    { name: 'sprite', url: 'https://tiles.openfreemap.org/sprites/ofm/sprite.json' },
    { name: 'glyphs', url: 'https://tiles.openfreemap.org/fonts/Noto%20Sans%20Bold/0-255.pbf' },
    { name: 'TileJSON', url: 'https://tiles.openfreemap.org/planet' },
  ];

  for (const { name, url } of critical) {
    const result = evaluateRequestFailures({
      failures: [abortedFailure({ url })],
      mapContent: visibleMap,
    });
    assert.equal(result.ok, false, name);
    assert.equal(result.tolerated.length, 0, name);
    assert.equal(result.fatal.length, 1, name);
    assert.equal(result.fatal[0].errorText, 'net::ERR_ABORTED', name);
  }
});

test('a tile that fails with a DNS, timeout or reset error stays fatal', () => {
  for (const errorText of [
    'net::ERR_NAME_NOT_RESOLVED',
    'net::ERR_TIMED_OUT',
    'net::ERR_CONNECTION_RESET',
    'net::ERR_CONNECTION_REFUSED',
  ]) {
    const result = evaluateRequestFailures({
      failures: [abortedFailure({ errorText })],
      mapContent: visibleMap,
    });
    assert.equal(result.ok, false, errorText);
    assert.equal(result.fatal.length, 1, errorText);
    assert.match(result.fatal[0].reason, /not a cancellation/, errorText);
  }
});

test('an HTTP 503 on a tile is never tolerated', () => {
  const verdict = classifyTileResponse({ url: `${TILESET}/2/0/0.pbf`, status: 503 });
  assert.equal(verdict.tolerable, false);
  assert.match(verdict.reason, /503/);

  const ok = classifyTileResponse({ url: `${TILESET}/2/0/0.pbf`, status: 200 });
  assert.equal(ok.tolerable, true);

  const notTile = classifyTileResponse({ url: 'https://tiles.openfreemap.org/fonts/a/0-255.pbf', status: 503 });
  assert.equal(notTile.tolerable, false);
});

test('an aborted request on another host stays fatal, even with visible content', () => {
  const hosts = [
    'https://cdn.example.org/planet/20261025_080012_pt/2/0/0.pbf',
    'https://tiles.openfreemap.org.example.net/planet/20261025_080012_pt/2/0/0.pbf',
    'https://api.kubus.site/api/artworks/art-1',
    'https://maps.googleapis.com/maps/api/js',
  ];

  for (const url of hosts) {
    const result = evaluateRequestFailures({
      failures: [abortedFailure({ url })],
      mapContent: visibleMap,
    });
    assert.equal(result.ok, false, url);
    assert.equal(result.tolerated.length, 0, url);
    assert.equal(classifyOpenFreeMapUrl(url).kind, 'foreign', url);
  }
});

test('tile-shaped URLs with impossible coordinates or methods are not tolerated', () => {
  assert.equal(classifyOpenFreeMapUrl(`${TILESET}/2/9/9.pbf`).kind, 'tile-out-of-range');
  assert.equal(classifyOpenFreeMapUrl(`${TILESET}/99/0/0.pbf`).kind, 'tile-out-of-range');

  const outOfRange = evaluateRequestFailures({
    failures: [abortedFailure({ url: `${TILESET}/2/9/9.pbf` })],
    mapContent: visibleMap,
  });
  assert.equal(outOfRange.ok, false);

  const post = evaluateRequestFailures({
    failures: [abortedFailure({ method: 'POST' })],
    mapContent: visibleMap,
  });
  assert.equal(post.ok, false);
});

test('a document or script resource type never counts as a tile cancellation', () => {
  for (const resourceType of ['document', 'script', 'stylesheet', 'image', 'font']) {
    const result = evaluateRequestFailures({
      failures: [abortedFailure({ resourceType })],
      mapContent: visibleMap,
    });
    assert.equal(result.ok, false, resourceType);
  }
});

test('in a mixed batch only the cancelled tile is tolerated and the style abort still fails', () => {
  const result = evaluateRequestFailures({
    failures: [
      abortedFailure(),
      abortedFailure({ url: 'https://tiles.openfreemap.org/styles/liberty.json' }),
    ],
    mapContent: visibleMap,
  });

  assert.equal(result.ok, false);
  assert.equal(result.tolerated.length, 1);
  assert.equal(result.fatal.length, 1);
  assert.match(result.fatal[0].url, /styles\/liberty\.json$/);
});

test('no failures means the policy passes without needing map content', () => {
  const result = evaluateRequestFailures({ failures: [], mapContent: null });
  assert.equal(result.ok, true);
  assert.equal(result.contentChecked, false);
});

test('the content assessment judges the newest attached map and ignores detached ones', () => {
  const snapshot = {
    maps: [
      { ...visibleMap.maps[0], id: 1 },
      { ...visibleMap.maps[0], id: 2, containerConnected: true, styleLoaded: false },
      { ...visibleMap.maps[0], id: 3, containerConnected: false },
    ],
  };
  const verdict = assessMapContentSnapshot(snapshot);
  assert.equal(verdict.visible, false);
  assert.deepEqual(verdict.reasons, ['style not loaded']);
  assert.equal(verdict.map.id, 2);
});

test('the browser-side map probe is valid script', () => {
  assert.doesNotThrow(() => new Function(MAP_CONTENT_PROBE_INIT));
});

test('the smoke wires this policy in instead of failing on every request failure', () => {
  const here = dirname(fileURLToPath(import.meta.url));
  const smoke = readFileSync(resolve(here, 'web_runtime_smoke.mjs'), 'utf8');
  assert.match(smoke, /from '\.\/lib\/map_request_policy\.mjs'/);
  assert.match(smoke, /evaluateRequestFailures\(/);
  assert.match(smoke, /MAP_CONTENT_PROBE_INIT/);
});
