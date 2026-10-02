import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const read = (name) => readFileSync(new URL(`../../${name}`, import.meta.url), 'utf8');

test('Flutter account discovery matches the checked-out backend JWT route', () => {
  const client = read('lib/services/backend_api_service_availability_transport.dart');
  const routes = read('backend/src/routes/availability.js');
  assert.match(client, /api\/availability\/account\/nodes/);
  assert.match(routes, /'\/account\/nodes',\s*verifyToken,/);
  assert.doesNotMatch(client, /api\/availability\/nodes\/me/);
});

test('only backend creation defines default scopes; historical verification does not normalize them', () => {
  const provider = read('lib/providers/availability_operator_provider.dart');
  const backend = read('backend/src/services/availabilityOperatorTokenService.js');
  assert.doesNotMatch(provider, /availabilityOperatorDefaultScopes/);
  assert.match(backend, /'availability:nodes:signal'/);
  assert.match(backend, /'compute:jobs:read'/);
  assert.match(backend, /'compute:jobs:write'/);
  const verification = backend.slice(backend.indexOf('async function verifyOperatorToken('), backend.indexOf('async function touchOperatorToken('));
  assert.ok(verification.length > 100, 'verification function must be inspected');
  assert.doesNotMatch(verification, /normalizeScopes\(/);
});
