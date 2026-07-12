import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildStableApiStub,
  isExpectedRequestFailure,
} from './web_runtime_contract.mjs';

function jsonBody(response) {
  return JSON.parse(response.body);
}

test('health stubs preserve ready and writable contracts', () => {
  const ready = jsonBody(buildStableApiStub('https://api.kubus.site/health/ready'));
  const writable = jsonBody(
    buildStableApiStub('https://bapi.kubus.site/health/writable'),
  );

  assert.deepEqual(ready, { status: 'ok', ready: true });
  assert.equal(writable.writable, true);
  assert.equal(writable.isWritable, true);
  assert.equal(writable.role, 'primary');
});

test('stats stub reflects requested identity, scope, and counters', () => {
  const response = buildStableApiStub(
    'https://api.kubus.site/api/stats/platform/global?metrics=artworks,posts&scope=public',
  );
  const { data } = jsonBody(response);

  assert.equal(data.entityType, 'platform');
  assert.equal(data.entityId, 'global');
  assert.equal(data.scope, 'public');
  assert.deepEqual(data.metrics, ['artworks', 'posts']);
  assert.deepEqual(data.counters, { artworks: 0, posts: 0 });
});

test('collection and telemetry stubs are empty and side-effect free', () => {
  const collection = jsonBody(
    buildStableApiStub('https://api.kubus.site/api/artworks?page=1&limit=100'),
  );
  const telemetry = buildStableApiStub(
    'https://api.kubus.site/api/analytics/app',
    'POST',
  );

  assert.deepEqual(collection.data, []);
  assert.equal(collection.pagination.total, 0);
  assert.deepEqual(telemetry, { status: 204, body: '' });
});

test('only the known MapLibre cancellation is an expected request failure', () => {
  assert.equal(
    isExpectedRequestFailure(
      'GET http://127.0.0.1:8090/local/maplibre-gl/maplibre-gl-csp.js?v=1 net::ERR_ABORTED',
    ),
    true,
  );
  assert.equal(
    isExpectedRequestFailure('GET https://api.kubus.site/health net::ERR_FAILED'),
    false,
  );
});

test('API stubs reject hosts outside the explicit QA boundary', () => {
  assert.throws(
    () => buildStableApiStub('https://example.com/api/artworks'),
    /Unsupported QA API host/,
  );
});
