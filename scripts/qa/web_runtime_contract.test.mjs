import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { buildStableApiStub } from './web_runtime_contract.mjs';
import { resolveBuildMetadata } from '../../scripts/resolve_ci_build_metadata.mjs';

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

test('CI build metadata keeps semantic versions manual and increments Android-safe builds', () => {
  const first = resolveBuildMetadata({
    version: '0.7.0',
    buildDate: '2026-07-14',
    runNumber: 42,
  });
  const next = resolveBuildMetadata({
    version: '0.7.0',
    buildDate: '2026-07-14',
    runNumber: 43,
  });
  const tomorrow = resolveBuildMetadata({
    version: '0.7.0',
    buildDate: '2026-07-15',
    runNumber: 1,
  });
  const dailyLimit = resolveBuildMetadata({
    version: '0.7.0',
    buildDate: '2026-07-14',
    runNumber: 10000,
  });

  assert.deepEqual(first, {
    version: '0.7.0',
    buildDate: '2026-07-14',
    buildNumber: 261950042,
  });
  assert.ok(next.buildNumber > first.buildNumber);
  assert.equal(dailyLimit.buildNumber, 261960000);
  assert.ok(tomorrow.buildNumber > next.buildNumber);
  assert.throws(
    () => resolveBuildMetadata({ version: '0.7', buildDate: '2026-07-14', runNumber: 1 }),
    /X\.Y\.Z/,
  );
});

test('CI applies its generated build metadata to every Flutter platform build', () => {
  const workflow = readFileSync(
    resolve(repoRoot, '.github', 'workflows', 'ci.yml'),
    'utf8',
  );
  const config = readFileSync(resolve(repoRoot, 'lib', 'config', 'config.dart'), 'utf8');

  assert.equal(
    (workflow.match(/Resolve CI build metadata/g) || []).length,
    1,
    'one job must resolve metadata and all Flutter platform jobs must consume it',
  );
  assert.match(workflow, /build_metadata:[\s\S]*?outputs:[\s\S]*?build_number:/);
  assert.match(workflow, /needs: \[guardrails, build_metadata\]/);
  assert.match(workflow, /--build-number="\$\{\{ needs\.build_metadata\.outputs\.build_number \}\}"/);
  assert.match(workflow, /KUBUS_BUILD_DATE: \$\{\{ needs\.build_metadata\.outputs\.build_date \}\}/);
  assert.match(config, /String\.fromEnvironment\(\s*'KUBUS_APP_VERSION'/);
  assert.match(config, /int\.fromEnvironment\(\s*'KUBUS_BUILD_NUMBER'/);
  assert.match(config, /String\.fromEnvironment\(\s*'KUBUS_BUILD_DATE'/);
});

test('Android CI reclaims disk before release compilation without dropping the debug gate', () => {
  const workflow = readFileSync(
    resolve(repoRoot, '.github', 'workflows', 'ci.yml'),
    'utf8',
  );
  const androidJob = workflow.slice(workflow.indexOf('\n  android:'), workflow.indexOf('\n  ios:'));

  assert.match(androidJob, /Reclaim hosted-runner disk for Android builds/);
  assert.match(androidJob, /docker image prune --all --force/);
  assert.match(androidJob, /test "\$available_kib" -ge 12582912/);
  assert.match(androidJob, /Compile Android debug APK[\s\S]*?Reclaim debug-only Android intermediates[\s\S]*?Compile unsigned Android release APK/);
  assert.match(androidJob, /rm -rf build\/app android\/.gradle/);
});

test('successful master CI publishes one immutable alpha release per version', () => {
  const workflow = readFileSync(
    resolve(repoRoot, '.github', 'workflows', 'deploy.yml'),
    'utf8',
  );

  assert.match(
    workflow,
    /signed_apk:[\s\S]*?github\.event_name == 'workflow_run'[\s\S]*?github\.event\.workflow_run\.conclusion == 'success'/,
  );
  assert.match(workflow, /release_tag="v\$\{version\}-alpha"/);
  assert.match(workflow, /releases\/tags\/\$release_tag/);
  assert.match(
    workflow,
    /Immutable release \$release_tag already exists; skipping signing and publication/,
  );
  assert.match(workflow, /should_build=false/);
  assert.match(
    workflow,
    /Tag \$release_tag exists without a GitHub Release; refusing to mutate it/,
  );
  assert.match(workflow, /allowUpdates:\s*false/);
  assert.match(workflow, /replacesArtifacts:\s*false/);
});

test('iOS publication signs a configured IPA from exact CI inputs before attaching it', () => {
  const ci = readFileSync(resolve(repoRoot, '.github', 'workflows', 'ci.yml'), 'utf8');
  const deploy = readFileSync(resolve(repoRoot, '.github', 'workflows', 'deploy.yml'), 'utf8');
  const releaseConfig = readFileSync(resolve(repoRoot, 'ios', 'Flutter', 'Release.xcconfig'), 'utf8');
  const project = readFileSync(
    resolve(repoRoot, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    'utf8',
  );

  assert.match(ci, /Retain exact iOS release build inputs/);
  assert.match(ci, /name: ios-release-inputs-\$\{\{ github\.sha \}\}/);
  assert.match(deploy, /signed_ipa:[\s\S]*?vars\.IOS_RELEASE_ENABLED == 'true'/);
  assert.match(deploy, /environment: ios-release/);
  assert.match(deploy, /IOS_DISTRIBUTION_CERTIFICATE_BASE64/);
  assert.match(deploy, /IOS_PROVISIONING_PROFILE_BASE64/);
  assert.match(deploy, /test "\$profile_app_id" = "\$IOS_TEAM_ID\.\$IOS_BUNDLE_ID"/);
  assert.match(deploy, /flutter build ipa --release/);
  assert.match(deploy, /codesign --verify --deep --strict/);
  assert.match(deploy, /gh release upload/);
  assert.match(deploy, /security delete-keychain/);
  assert.match(
    releaseConfig,
    /KUBUS_IOS_BUNDLE_ID=com\.art\.kubus\n#include\? "Release-CI\.xcconfig"/,
  );
  assert.match(releaseConfig, /#include\? "Release-CI\.xcconfig"/);
  const appBundleIds = project
    .match(/PRODUCT_BUNDLE_IDENTIFIER = "\$\(KUBUS_IOS_BUNDLE_ID\)";/g) ?? [];
  assert.equal(appBundleIds.length, 3, 'all Runner configurations must share the production bundle ID');
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
  assert.match(workflow, /--header 'Cache-Control: no-cache'/);
  assert.match(workflow, /--header 'Pragma: no-cache'/);
  assert.doesNotMatch(workflow, /deploy_sha=/);
});

test('web deployment retries SSH reachability before mutating the release root', () => {
  const workflow = readFileSync(
    resolve(repoRoot, '.github', 'workflows', 'deploy.yml'),
    'utf8',
  );

  assert.match(workflow, /Wait for SSH deployment endpoint/);
  assert.match(workflow, /for attempt in 1 2 3 4 5 6/);
  assert.match(workflow, /timeout 15 bash -c/);
  assert.match(workflow, /no remote files were changed/);
  assert.match(
    workflow,
    /Wait for SSH deployment endpoint[\s\S]*?Prepare versioned remote upload directory/,
  );
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
