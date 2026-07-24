import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { buildStableApiStub } from './web_runtime_contract.mjs';
import {
  classifyBrowserFailures,
  parseTakeoverEventDetail,
} from './public_flutter_takeover_smoke_support.mjs';
import { resolveBuildMetadata } from '../../scripts/resolve_ci_build_metadata.mjs';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const workflow = (name) => readFileSync(
  resolve(repoRoot, '.github', 'workflows', name),
  'utf8',
);
const deployAction = () => readFileSync(
  resolve(repoRoot, '.github', 'actions', 'deploy-web-artifact', 'action.yml'),
  'utf8',
);

test('takeover smoke parses the serialized Flutter event contract', () => {
  assert.deepEqual(
    parseTakeoverEventDetail('{"type":"artwork","id":"art-1","path":"/en/artworks/art-1"}'),
    { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1' },
  );
  assert.equal(parseTakeoverEventDetail('{invalid'), null);
});

test('takeover smoke separates an explicitly configured standby probe failure', () => {
  const result = classifyBrowserFailures({
    consoleErrors: [
      "Access to fetch at 'https://bapi.kubus.site/health/writable' was blocked by CORS policy",
      'Failed to load resource: net::ERR_FAILED',
    ],
    failedRequests: [
      { url: 'https://bapi.kubus.site/health/writable', error: 'net::ERR_FAILED' },
    ],
    optionalStandbyProbeUrl: 'https://bapi.kubus.site',
  });

  assert.deepEqual(result.criticalConsoleErrors, []);
  assert.deepEqual(result.criticalFailedRequests, []);
  assert.equal(result.optionalStandbyFailures.length, 1);
  assert.equal(result.optionalStandbyConsoleErrors.length, 2);
});

test('takeover smoke keeps unrelated browser failures fatal', () => {
  const result = classifyBrowserFailures({
    consoleErrors: ['Application exploded'],
    failedRequests: [
      { url: 'https://api.kubus.site/api/artworks/art-1', error: 'net::ERR_FAILED' },
    ],
    optionalStandbyProbeUrl: 'https://bapi.kubus.site',
  });

  assert.deepEqual(result.criticalConsoleErrors, ['Application exploded']);
  assert.equal(result.criticalFailedRequests.length, 1);
});

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
  const buildWorkflow = workflow('web-artifact.yml');
  const deploy = deployAction();
  const stepStart = buildWorkflow.indexOf('- name: Upload immutable web artifact');
  assert.notEqual(stepStart, -1, 'CI must upload the immutable web bundle');

  const nextStep = buildWorkflow.indexOf('\n      - name:', stepStart + 1);
  const uploadStep = buildWorkflow.slice(
    stepStart,
    nextStep === -1 ? buildWorkflow.length : nextStep,
  );
  assert.match(uploadStep, /\binclude-hidden-files:\s*true\b/);
  assert.match(buildWorkflow, /sha256sum -c SHA256SUMS/);
  assert.match(
    deploy,
    /Verify provenance, checksums, and package archive[\s\S]*?\(cd build\/web && sha256sum -c SHA256SUMS\)[\s\S]*?Apply and verify host-local development protection/,
  );
  assert.doesNotMatch(buildWorkflow, /DEV_HTPASSWD_FILE|AuthUserFile/);
});

test('web-root migration remains an explicit manual deployment action', () => {
  for (const name of ['deploy-development.yml', 'release-production.yml']) {
    const caller = workflow(name);
    assert.match(caller, /bootstrap_web_root:\s*[\s\S]*?default:\s*false\s*[\s\S]*?type:\s*boolean/);
    assert.match(caller, /bootstrap_web_root: \$\{\{ github\.event_name == 'workflow_dispatch' && inputs\.bootstrap_web_root \}\}/);
  }
  const deploy = deployAction();
  assert.equal(
    (deploy.match(/if:\s*\$\{\{[^}\r\n]*inputs\.bootstrap_web_root == 'true'[^}\r\n]*\}\}/g) || []).length,
    2,
    "both bootstrap steps must require the explicit caller input to equal the string 'true'",
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

test('release artifact workflows propagate generated metadata to platform builds', () => {
  const web = workflow('web-artifact.yml');
  const mobile = workflow('mobile-release.yml');
  const config = readFileSync(resolve(repoRoot, 'lib', 'config', 'config.dart'), 'utf8');

  assert.match(web, /id: metadata[\s\S]*?resolve_ci_build_metadata\.mjs/);
  assert.match(web, /--build-number="\$\{\{ steps\.metadata\.outputs\.build_number \}\}"/);
  assert.match(web, /KUBUS_BUILD_DATE: \$\{\{ steps\.metadata\.outputs\.build_date \}\}/);
  assert.match(mobile, /build_number: \$\{\{ steps\.metadata\.outputs\.build_number \}\}/);
  assert.equal((mobile.match(/--build-number="\$\{\{ needs\.source\.outputs\.build_number \}\}"/g) || []).length, 3);
  assert.match(config, /String\.fromEnvironment\(\s*'KUBUS_APP_VERSION'/);
  assert.match(config, /int\.fromEnvironment\(\s*'KUBUS_BUILD_NUMBER'/);
  assert.match(config, /String\.fromEnvironment\(\s*'KUBUS_BUILD_DATE'/);
});

test('Android PR compilation stays unsigned and signing remains release-only', () => {
  const validation = workflow('pr-validation.yml');
  const mobile = workflow('mobile-release.yml');
  const androidJob = validation.slice(validation.indexOf('\n  android:'), validation.indexOf('\n  ios:'));

  assert.match(androidJob, /needs\.changes\.outputs\.android == 'true'/);
  assert.match(androidJob, /flutter build apk --release/);
  assert.doesNotMatch(androidJob, /ANDROID_KEYSTORE|android-release/);
  assert.match(mobile, /environment: android-release/);
  assert.match(mobile, /ANDROID_KEYSTORE_BASE64/);
});

test('mobile publication is explicit, master-derived, and immutable', () => {
  const mobile = workflow('mobile-release.yml');

  assert.match(mobile, /tags: \['v\*'\]/);
  assert.match(mobile, /git merge-base --is-ancestor "\$SOURCE_SHA" origin\/master/);
  assert.doesNotMatch(mobile, /workflow_run|branches:\s*\[?master/);
  assert.match(mobile, /environment: android-release/);
  assert.match(mobile, /environment: ios-release/);
  assert.match(mobile, /allowUpdates:\s*false/);
  assert.match(mobile, /replacesArtifacts:\s*false/);
});

test('iOS publication signs a configured IPA from exact CI inputs before attaching it', () => {
  const mobile = workflow('mobile-release.yml');
  const signing = readFileSync(resolve(repoRoot, 'scripts', 'deploy', 'configure_ios_signing.sh'), 'utf8');
  const releaseConfig = readFileSync(resolve(repoRoot, 'ios', 'Flutter', 'Release.xcconfig'), 'utf8');
  const buildConfig = readFileSync(resolve(repoRoot, 'scripts', 'prepare_public_build_config.mjs'), 'utf8');
  const project = readFileSync(
    resolve(repoRoot, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    'utf8',
  );

  assert.match(mobile, /if: \$\{\{ vars\.IOS_RELEASE_ENABLED == 'true' \}\}/);
  assert.match(mobile, /environment: ios-release/);
  assert.match(mobile, /IOS_DISTRIBUTION_CERTIFICATE_BASE64/);
  assert.match(mobile, /IOS_PROVISIONING_PROFILE_BASE64/);
  assert.match(signing, /\[ "\$profile_app_id" = "\$IOS_TEAM_ID\.\$IOS_BUNDLE_ID" \]/);
  assert.match(mobile, /flutter build ipa --release/);
  assert.match(mobile, /codesign --verify --deep --strict/);
  assert.match(mobile, /ncipollo\/release-action@[0-9a-f]{40}/);
  assert.match(mobile, /security delete-keychain/);
  assert.match(
    releaseConfig,
    /KUBUS_IOS_BUNDLE_ID=com\.art\.kubus\r?\n#include\? "Release-CI\.xcconfig"/,
  );
  assert.match(releaseConfig, /#include\? "Release-CI\.xcconfig"/);
  assert.match(releaseConfig, /#include\? "Google-CI\.xcconfig"/);
  assert.match(buildConfig, /Google-CI\.xcconfig/);
  assert.match(buildConfig, /KUBUS_GOOGLE_REVERSED_IOS_CLIENT_ID/);
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

test('canonical public takeover waits for exact entity readiness and keeps root assets', () => {
  const bootstrap = readFileSync(
    resolve(repoRoot, 'web', 'flutter_bootstrap.js'),
    'utf8',
  );
  const takeover = readFileSync(
    resolve(repoRoot, 'web', 'public_flutter_takeover.js'),
    'utf8',
  );

  assert.match(bootstrap, /entrypointBaseUrl:\s*"\/"/);
  assert.match(bootstrap, /assetBase:\s*"\/"/);
  assert.match(bootstrap, /canvasKitBaseUrl:\s*"\/canvaskit\/"/);
  assert.match(bootstrap, /engineConfig\.hostElement = takeoverHost/);
  assert.match(bootstrap, /flutterServiceWorkerVersion\s*=\s*\{\{flutter_service_worker_version\}\}/);
  assert.match(bootstrap, /__kubusBuildVersion/);
  assert.match(bootstrap, /serviceWorkerVersion:\s*flutterServiceWorkerVersion/);
  assert.match(takeover, /kubus:public-entity-ready/);
  assert.match(takeover, /kubus:public-entity-route-parsed/);
  assert.match(takeover, /public_entity_route_parsed/);
  assert.match(takeover, /value\.type === expected\.type/);
  assert.match(takeover, /value\.id === expected\.id/);
  assert.match(takeover, /value\.path === expected\.path/);
  assert.match(takeover, /globalThis\.location\.pathname === expected\.path/);
  assert.match(takeover, /publicDocument\.inert = true/);
  assert.match(takeover, /host\.setAttribute\("aria-hidden", "true"\)/);
  assert.match(takeover, /onBootstrapResourceError/);
  assert.match(takeover, /flutter_takeover_failed/);
  assert.doesNotMatch(takeover, /setTimeout\([^)]*,\s*2000\)/);
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
  const smoke = readFileSync(resolve(repoRoot, 'scripts', 'deploy', 'smoke_production_web.sh'), 'utf8');

  assert.match(smoke, /public HTML unexpectedly loads the interactive app bundle/i);
  assert.match(smoke, /__deploy_unknown_\$SOURCE_SHA/);
  assert.match(smoke, /write-out '%\{http_code\}'.* = 404/);
  assert.match(smoke, /--header 'Cache-Control: no-cache'/);
  assert.match(smoke, /--header 'Pragma: no-cache'/);
  assert.doesNotMatch(smoke, /deploy_sha=/);
});

test('deployed public takeover smoke remains opt-in and verifies the complete handoff', () => {
  const smoke = readFileSync(
    resolve(repoRoot, 'scripts', 'qa', 'public_flutter_takeover_smoke.mjs'),
    'utf8',
  );
  const qaPackage = readFileSync(resolve(repoRoot, 'scripts', 'qa', 'package.json'), 'utf8');
  const buildWorkflow = workflow('web-artifact.yml');

  assert.match(qaPackage, /"qa:public-takeover": "node \.\/public_flutter_takeover_smoke\.mjs"/);
  assert.match(smoke, /EXPECT_PUBLIC_FLUTTER_TAKEOVER/);
  assert.match(smoke, /id=\["'\]public-document/);
  assert.match(smoke, /id=\["'\]flutter-host/);
  assert.match(smoke, /public_flutter_takeover\\\.js/);
  assert.match(smoke, /flutter_bootstrap\\\.js/);
  assert.match(smoke, /kubus:public-entity-ready/);
  assert.match(smoke, /did not emit canonical route-parsed/);
  assert.match(smoke, /route-parsed ID did not match requested URL/);
  assert.match(smoke, /route-parsed path did not match requested URL/);
  assert.match(smoke, /kubus-takeover-complete/);
  assert.match(smoke, /flutter_service_worker\.js/);
  assert.match(smoke, /name: 'desktop', viewport: \{ width: 1440, height: 1000 \}/);
  assert.match(smoke, /name: 'mobile', viewport: \{ width: 390, height: 844 \}/);
  assert.match(smoke, /PUBLIC_TAKEOVER_BROWSER_REPETITIONS/);
  assert.match(smoke, /expectTakeover \? 2 : 1/);
  assert.match(smoke, /const browser = await browserType\.launch/);
  assert.match(smoke, /finally \{\s*await browser\.close\(\);/);
  // The WAF bypass secret must be scoped to the deployment origin (raw fetches
  // and per-request Playwright routing) and never broadcast context-wide.
  assert.match(smoke, /function bypassHeadersFor\(/);
  assert.match(smoke, /\.origin === targetOrigin/);
  assert.doesNotMatch(smoke, /extraHTTPHeaders/);
  // Playwright routing injects the header only on the same-origin branch.
  assert.match(
    smoke,
    /if \(sameOrigin\) \{\s*await route\.continue\(\{ headers: \{ \.\.\.request\.headers\(\), 'x-deploy-smoke': smokeBypassToken \} \}\);\s*\} else \{\s*await route\.continue\(\);/,
  );
  assert.match(buildWorkflow, /--dart-define=PUBLIC_FLUTTER_TAKEOVER_ENABLED=true/);
  assert.match(buildWorkflow, /--dart-define=SEO_PUBLIC_PAGES_ENABLED=true/);
});

test('production SEO contract scopes the WAF header to the origin and classifies 415 without leaking the token', () => {
  const contract = readFileSync(
    resolve(repoRoot, 'scripts', 'qa', 'production_seo_contract.mjs'),
    'utf8',
  );
  // The header set is derived from the token and only spread into same-origin
  // requests (all fetches target `${ORIGIN}${path}`); no absolute external URL
  // is ever fetched with the bypass header.
  assert.match(contract, /const BYPASS_HEADERS = SMOKE_BYPASS_TOKEN \? \{ 'X-Deploy-Smoke': SMOKE_BYPASS_TOKEN \} : \{\};/);
  assert.match(contract, /httpFetch\(`\$\{ORIGIN\}\$\{path\}`/);
  assert.doesNotMatch(contract, /fetch\(`https?:\/\/\$\{?(?!ORIGIN)/);
  // A 415 anywhere is surfaced as a WAF diagnosis, never as a content failure,
  // and the token value is never printed.
  assert.match(contract, /if \(response\.status === 415\) wafBlockObserved = true;/);
  assert.match(contract, /WAF diagnosis \(token value never shown\)/);
  assert.doesNotMatch(contract, /console\.(log|error)\([^\n]*SMOKE_BYPASS_TOKEN/);
});

test('production smoke fails closed on a WAF 415 with a token-safe diagnosis', () => {
  const smoke = readFileSync(resolve(repoRoot, 'scripts', 'deploy', 'smoke_production_web.sh'), 'utf8');
  const diagnostics = readFileSync(resolve(repoRoot, 'scripts', 'deploy', 'waf_smoke_diagnostics.sh'), 'utf8');

  // The smoke sources the shared diagnosis and calls it before failing the root
  // assertion; it still dies (fail closed) -- a 415 is never a pass.
  assert.match(smoke, /waf_smoke_diagnostics\.sh/);
  assert.match(smoke, /waf_diagnose "\$origin" "\$root_status" "\$root_target"/);
  assert.match(smoke, /die "root canonicalization expected 308/);
  // The diagnosis never echoes the token and rejects the ineffective .htaccess
  // pseudo-fix explicitly.
  assert.doesNotMatch(diagnostics, /echo[^\n]*\$SMOKE_BYPASS_TOKEN|printf[^\n]*\$SMOKE_BYPASS_TOKEN/);
  assert.match(diagnostics, /an \.htaccess rule cannot fix this/);
});

test('smoke clients route through the SSH SOCKS egress when SMOKE_SOCKS_PROXY is set', () => {
  const prodSmoke = readFileSync(resolve(repoRoot, 'scripts', 'deploy', 'smoke_production_web.sh'), 'utf8');
  const devSmoke = readFileSync(resolve(repoRoot, 'scripts', 'deploy', 'smoke_development_web.sh'), 'utf8');
  const seo = readFileSync(resolve(repoRoot, 'scripts', 'qa', 'production_seo_contract.mjs'), 'utf8');
  const takeover = readFileSync(resolve(repoRoot, 'scripts', 'qa', 'public_flutter_takeover_smoke.mjs'), 'utf8');

  // curl clients add --proxy from SMOKE_SOCKS_PROXY, only when it is set.
  for (const smoke of [prodSmoke, devSmoke]) {
    assert.match(smoke, /SMOKE_SOCKS_PROXY/);
    assert.match(smoke, /smoke_proxy_args=\(--proxy "\$SMOKE_SOCKS_PROXY"\)/);
  }

  // Node SEO contract routes through Playwright's SOCKS-capable request API only
  // when proxying (no new dependency), and adapts it to the fetch shape.
  assert.match(seo, /const SMOKE_SOCKS_PROXY = \(process\.env\.SMOKE_SOCKS_PROXY \?\? ''\)\.trim\(\);/);
  assert.match(seo, /await import\('playwright'\)/);
  assert.match(seo, /await httpFetch\(`\$\{ORIGIN\}\$\{path\}`/);

  // Playwright takeover routes both the browsers and the raw probes through the
  // proxy; the raw probes go through an API request context, browsers via launch.
  assert.match(takeover, /const smokeSocksProxy = \(process\.env\.SMOKE_SOCKS_PROXY \|\| ''\)\.trim\(\);/);
  assert.match(takeover, /\.\.\.\(smokeProxyOption \? \{ proxy: smokeProxyOption \} : \{\}\)/);
  assert.match(takeover, /await rawFetch\(/);
  assert.doesNotMatch(takeover, /await fetch\(/);
});

test('production deployment enforces and can roll back the canonical takeover smoke', () => {
  const deploy = deployAction();
  const release = workflow('release-production.yml');
  const smoke = readFileSync(resolve(repoRoot, 'scripts', 'deploy', 'smoke_production_web.sh'), 'utf8');

  // The composite action consumes takeover configuration as inputs; a composite
  // action cannot read the `vars` context directly.
  assert.match(deploy, /EXPECT_PUBLIC_FLUTTER_TAKEOVER: \$\{\{ inputs\.expect_public_flutter_takeover/);
  assert.match(deploy, /PUBLIC_TAKEOVER_URL: \$\{\{ inputs\.public_takeover_url \}\}/);
  assert.match(deploy, /PUBLIC_TAKEOVER_MISSING_URL: \$\{\{ inputs\.public_takeover_missing_url \}\}/);
  assert.match(deploy, /PUBLIC_TAKEOVER_OPTIONAL_STANDBY_URL: \$\{\{ inputs\.public_takeover_optional_standby_url \}\}/);

  // The environment-bound production caller forwards those variables from `vars`.
  assert.match(release, /expect_public_flutter_takeover: \$\{\{ vars\.EXPECT_PUBLIC_FLUTTER_TAKEOVER \}\}/);
  assert.match(release, /public_takeover_url: \$\{\{ vars\.PUBLIC_TAKEOVER_URL \}\}/);
  assert.match(release, /public_takeover_missing_url: \$\{\{ vars\.PUBLIC_TAKEOVER_MISSING_URL \}\}/);
  assert.match(release, /public_takeover_optional_standby_url: \$\{\{ vars\.PUBLIC_TAKEOVER_OPTIONAL_STANDBY_URL \}\}/);

  assert.match(smoke, /npx playwright install --with-deps chromium firefox/);
  assert.match(smoke, /npm --prefix scripts\/qa run qa:public-takeover/);
  assert.match(
    deploy,
    /id: production_smoke[\s\S]*?smoke_production_web\.sh[\s\S]*?Roll back failed post-promotion smoke[\s\S]*?steps\.production_smoke\.outcome == 'failure'/,
  );
});

test('web deployment retries SSH reachability before mutating the release root', () => {
  const deploy = deployAction();

  assert.match(deploy, /Wait for SSH deployment endpoint/);
  assert.match(deploy, /for attempt in 1 2 3 4 5 6/);
  assert.match(deploy, /timeout 15 bash -c/);
  assert.match(deploy, /no remote files were changed/);
  assert.match(
    deploy,
    /Wait for SSH deployment endpoint[\s\S]*?Prepare versioned incoming directory/,
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
