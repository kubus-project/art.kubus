import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { buildStableApiStub } from './web_runtime_contract.mjs';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');

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

test('API stubs reject hosts outside the explicit QA boundary', () => {
  assert.throws(
    () => buildStableApiStub('https://example.com/api/artworks'),
    /Unsupported QA API host/,
  );
});

test('immutable web artifact preserves files covered by its checksum manifest', () => {
  const workflow = readFileSync(
    resolve(repoRoot, '.github', 'workflows', 'ci.yml'),
    'utf8',
  );
  const stepStart = workflow.indexOf('- name: Upload immutable web bundle');
  assert.notEqual(stepStart, -1, 'CI must upload the immutable web bundle');

  const nextStep = workflow.indexOf('\n      - name:', stepStart + 1);
  const uploadStep = workflow.slice(
    stepStart,
    nextStep === -1 ? workflow.length : nextStep,
  );
  assert.match(uploadStep, /\binclude-hidden-files:\s*true\b/);
});

test('web-root migration remains an explicit manual deployment action', () => {
  const workflow = readFileSync(
    resolve(repoRoot, '.github', 'workflows', 'deploy.yml'),
    'utf8',
  );
  assert.match(
    workflow,
    /bootstrap_web_root:\s*[\s\S]*?default:\s*false\s*[\s\S]*?type:\s*boolean/,
  );

  const manualGate =
    "if: ${{ github.event_name == 'workflow_dispatch' && inputs.bootstrap_web_root }}";
  assert.equal(
    workflow.split(manualGate).length - 1,
    2,
    'both bootstrap steps must require an explicit manual dispatch',
  );
});

test('Flutter index positions art.kubus as an open art map', () => {
  const html = readFileSync(resolve(repoRoot, 'web', 'index.html'), 'utf8');

  assert.match(html, /<title>art\.kubus — Open Art Map and Community Platform<\/title>/);
  assert.match(html, /open, community-led art map/);
  assert.match(html, /"@type": "WebSite"/);
  assert.match(html, /<link rel="canonical" href="https:\/\/app\.kubus\.site\/en">/);
  assert.match(html, /"@type": "Organization"/);
  assert.match(html, /"@type": "WebApplication"/);
  assert.doesNotMatch(html, /<meta name="keywords"/);
  assert.doesNotMatch(html, /icons\/Icon-512\.png[^\n]*twitter:image/);
  assert.doesNotMatch(html, /explicitLang|slTitle|legacyHeads/);
});

test('web routing reserves public HTML, interactive app and real 404 surfaces', () => {
  const htaccess = readFileSync(resolve(repoRoot, 'web', '.htaccess'), 'utf8');
  const gateway = readFileSync(resolve(repoRoot, 'web', 'seo-proxy.php'), 'utf8');
  const notFound = readFileSync(resolve(repoRoot, 'web', '404.html'), 'utf8');

  assert.match(htaccess, /seo-proxy\.php \[L,QSA\]/);
  assert.doesNotMatch(htaccess, /\[P,L,NE\]/);
  assert.match(htaccess, /\^app\(\?:\/\.\*\)\?\$ index\.html/);
  assert.match(htaccess, /Unknown paths are real 404s/);
  assert.match(htaccess, /RewriteRule \^ - \[R=404,L\]/);
  assert.match(gateway, /const KUBUS_SEO_UPSTREAM_ORIGIN = 'https:\/\/api\.kubus\.site'/);
  assert.match(gateway, /\$method !== 'GET' && \$method !== 'HEAD'/);
  assert.match(gateway, /CURLOPT_FOLLOWLOCATION => false/);
  assert.match(gateway, /CURLOPT_PROTOCOLS/);
  assert.match(gateway, /X-Robots-Tag: noindex, follow/);
  assert.match(gateway, /Cache-Control: no-store, max-age=0/);
  assert.match(gateway, /if \(\$status >= 400\)/);
  assert.doesNotMatch(gateway, /HTTP_(?:AUTHORIZATION|COOKIE)/);
  assert.doesNotMatch(gateway, /getenv\s*\(/);
  assert.match(notFound, /<meta name="robots" content="noindex, follow">/);
  assert.match(notFound, /href="\/en\/artworks"/);
});

test('production smoke verifies public HTML and unknown-route status', () => {
  const workflow = readFileSync(
    resolve(repoRoot, '.github', 'workflows', 'deploy.yml'),
    'utf8',
  );

  assert.match(workflow, /Public HTML unexpectedly loads the interactive app bundle/);
  assert.match(workflow, /__deploy_unknown_\$\{SOURCE_SHA\}/);
  assert.match(workflow, /test .*http_code.* = '404'/);
});

test('runtime smoke does not trigger the service-worker reload escape hatch', () => {
  const smoke = readFileSync(
    resolve(repoRoot, 'scripts', 'qa', 'web_runtime_smoke.mjs'),
    'utf8',
  );

  assert.match(smoke, /page\.goto\(`\$\{appUrl\}\/`/);
  assert.doesNotMatch(smoke, /page\.goto\([^\n]*clear_sw/);
  assert.doesNotMatch(smoke, /isExpectedRequestFailure/);
});
