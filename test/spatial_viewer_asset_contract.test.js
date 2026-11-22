// Contract for the bundled spatial viewer asset and the CSP it runs under on the web.
// Run with: node --test test/spatial_viewer_asset_contract.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const root = path.resolve(__dirname, '..');
const read = (...parts) => fs.readFileSync(path.join(root, ...parts), 'utf8');

test('Spark is pinned at an MIT release and three satisfies its peer range', () => {
  const pkg = JSON.parse(read('assets', 'spatial_viewer', 'package.json'));
  assert.equal(pkg.dependencies['@sparkjsdev/spark'], '2.4.0');
  const lock = JSON.parse(read('assets', 'spatial_viewer', 'package-lock.json'));
  const spark = lock.packages['node_modules/@sparkjsdev/spark'];
  assert.equal(spark.version, '2.4.0');
  assert.equal(spark.license, 'MIT');
  const three = lock.packages['node_modules/three'];
  assert.equal(three.version, pkg.dependencies.three);
  const [major, minor] = three.version.split('.').map(Number);
  const [needMajor, needMinor] = spark.peerDependencies.three.replace('>=', '').split('.').map(Number);
  assert.ok(major > needMajor || (major === needMajor && minor >= needMinor), 'three satisfies the Spark peer range');
});

test('third-party notices name Spark and Three.js with their MIT licences', () => {
  const notices = read('THIRD_PARTY_NOTICES.md');
  assert.match(notices, /@sparkjsdev\/spark.{0,10}2\.4\.0/);
  assert.match(notices, /three.{0,8}0\.185\.1/);
  for (const file of ['SPARK-MIT.txt', 'THREE-MIT.txt']) {
    assert.match(read('third_party', 'licenses', file), /^The MIT License/);
    assert.ok(notices.includes(`third_party/licenses/${file}`));
  }
});

test('the notices also cover what Spark bundles: fflate and the WASM crates', () => {
  const notices = read('THIRD_PARTY_NOTICES.md');
  assert.match(read('third_party', 'licenses', 'FFLATE-MIT.txt'), /^MIT License[^]*Arjun Barrett/);
  assert.ok(notices.includes('third_party/licenses/FFLATE-MIT.txt'));
  const crates = read('third_party', 'licenses', 'SPARK-WASM-CRATES.txt');
  assert.ok(notices.includes('third_party/licenses/SPARK-WASM-CRATES.txt'));
  assert.doesNotMatch(crates, /GPL|AGPL|LGPL|Proprietary/i, 'no copyleft or proprietary crate');
  // Every crate carries its own notice: the MIT text (or the Zlib text) plus a copyright line or holder.
  const sections = crates.split(/^-{78}$/m).slice(1);
  assert.equal(sections.length, 20, 'one licence section per listed crate');
  for (const section of sections) {
    const title = section.trim().split(String.fromCharCode(10))[0];
    assert.match(section, /Copyright|\(C\) 20|Holder:/, `${title} names its copyright holder`);
    assert.match(section, /Permission is hereby granted|Permission is granted to anyone/, `${title} carries its licence text`);
  }
});

test('viewer source is valid UTF-8 and the shipped bundle carries no replacement character', () => {
  const replacement = String.fromCharCode(0xfffd);
  const decoder = new TextDecoder('utf-8', { fatal: true });
  const source = decoder.decode(fs.readFileSync(path.join(root, 'assets', 'spatial_viewer', 'src', 'viewer.js')));
  assert.ok(!source.includes(replacement));
  const bundle = read('assets', 'spatial_viewer', 'viewer.bundle.js');
  assert.ok(!bundle.includes(replacement), 'a lone CP1252 byte became U+FFFD once; it must not come back');
});

test('the viewer pauses its render loop and does not swallow page scroll', () => {
  const source = read('assets', 'spatial_viewer', 'src', 'viewer.js');
  assert.ok(source.includes('IntersectionObserver'));
  assert.ok(source.includes('visibilityState'));
  assert.ok(source.includes('document.activeElement !== canvas'));
  assert.equal(source.split('requestAnimationFrame(').length - 1, 1, 'the loop is armed in one guarded place only');
  assert.ok(source.includes('shouldRun()'));
  // Touch pitch needs the page to claim the gesture; the web host keeps the iframe inert instead.
  const html = read('assets', 'spatial_viewer', 'index.html');
  assert.ok(html.includes('touch-action:none'));
  assert.ok(!html.includes('pan-y'));
});

test('the viewer echoes the attempt id and speaks the activation protocol', () => {
  const source = read('assets', 'spatial_viewer', 'src', 'viewer.js');
  assert.match(source, /get\("a"\)/);
  assert.match(source, /payload\.attempt = attemptId/);
  for (const token of ['"activate"', '"deactivate"', 'post("escape")']) {
    assert.ok(source.includes(token), `viewer source speaks ${token}`);
  }
  const widget = read('lib', 'widgets', 'spatial', 'spatial_viewer_web.dart');
  assert.ok(widget.includes("'a': '${_session.attempt}'"), 'the host puts the attempt in the iframe URL');
  assert.ok(widget.includes("'${data['attempt']}' != '${_session.attempt}'"), 'the host drops other attempts');
  assert.ok(widget.includes("pointerEvents = inert ? 'none' : 'auto'"), 'the iframe is inert until activated');
});

test('the viewer page allows Spark WASM and stays closed otherwise', () => {
  const html = read('assets', 'spatial_viewer', 'index.html');
  const csp = /Content-Security-Policy" content="([^"]+)"/.exec(html)[1];
  assert.match(csp, /script-src 'self' 'wasm-unsafe-eval'/);
  assert.match(csp, /default-src 'none'/);
  assert.doesNotMatch(csp.split(';').find((part) => part.trim().startsWith('script-src')), /'unsafe-inline'|'unsafe-eval'/);
});

test('the shipped bundle carries the host protocol and the manifest transform', () => {
  const bundle = read('assets', 'spatial_viewer', 'viewer.bundle.js');
  for (const token of ['kubusSpatialViewerCommand', 'kubusSpatialViewer', 'column-major', '__spatialDebug']) {
    assert.ok(bundle.includes(token), `bundle contains ${token}`);
  }
  const source = read('assets', 'spatial_viewer', 'src', 'viewer.js');
  assert.match(source, /matrix\.fromArray\(matrix\)/);
});

test('the SEO takeover policy lets the page frame its own viewer, nothing else new', () => {
  const php = read('web', 'seo-proxy.php');
  const csp = /const KUBUS_TAKEOVER_CSP = "([^"]+)"/.exec(php)[1];
  assert.match(csp, /frame-src 'self' https:\/\/accounts\.google\.com;/);
  assert.match(csp, /frame-ancestors 'none'/);
  assert.match(csp, /default-src 'none'/);
});

test('the static HTML policy already permits the viewer frame and its WASM', () => {
  const htaccess = read('web', '.htaccess');
  const csp = /Header set Content-Security-Policy "([^"]+)"/.exec(htaccess)[1];
  assert.match(csp, /frame-src 'self'/);
  assert.match(csp, /'wasm-unsafe-eval'/);
  assert.match(csp, /worker-src 'self' blob:/);
  assert.match(csp, /connect-src 'self' https:/);
});

test('the manifest transform rules refuse projective, sheared, mirrored and absurd placements', async () => {
  const { acceptedMatrix, acceptedPosition, acceptedScale } = await import(
    pathToFileURL(path.join(root, 'assets', 'spatial_viewer', 'src', 'manifest_transform.mjs')).href
  );
  const upright = [0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
  const edit = (edits) => upright.map((value, i) => (i in edits ? edits[i] : value));
  assert.ok(acceptedMatrix(upright), 'the Node upright matrix passes');
  assert.ok(acceptedMatrix(edit({ 0: 0, 1: 2, 4: -2, 10: 3, 12: 5, 13: -4, 14: 1 })), 'rotation, scale and translation pass');
  assert.ok(!acceptedMatrix(edit({ 3: 0.5 })), 'projective bottom row');
  assert.ok(!acceptedMatrix(edit({ 15: 2 })), 'bottom-right is not 1');
  assert.ok(!acceptedMatrix(edit({ 4: -1, 5: 0.5 })), 'shear');
  assert.ok(!acceptedMatrix(edit({ 10: -1 })), 'mirror');
  assert.ok(!acceptedMatrix(edit({ 12: 1e9 })), 'translation out of bounds');
  assert.ok(!acceptedMatrix(edit({ 0: 0, 1: 1e9 })), 'scale too large');
  assert.ok(!acceptedMatrix(edit({ 0: 0, 1: 1e-9 })), 'scale too small');
  assert.ok(!acceptedMatrix(edit({ 0: Number.NaN })), 'non-finite');
  assert.ok(!acceptedMatrix(upright.slice(0, 15)), 'wrong length');
  assert.ok(acceptedPosition([0, 1e6, 0]) && !acceptedPosition([0, 1e12, 0]) && !acceptedPosition([0, 1]));
  assert.ok(acceptedScale(2) && acceptedScale([1, 1, 1e4]) && !acceptedScale(1e30) && !acceptedScale(0) && !acceptedScale([1, 1, 1e-12]));
});

test('the viewer applies those rules to the fallback fields as well as the matrix', () => {
  const source = read('assets', 'spatial_viewer', 'src', 'viewer.js');
  for (const token of ['acceptedMatrix(matrix)', 'acceptedPosition(position)', 'acceptedScale(scale)']) {
    assert.ok(source.includes(token), `viewer.js uses ${token}`);
  }
});

test('the MIT notices ship inside the bundle and as an app asset, not only in the repository', () => {
  const bundle = read('assets', 'spatial_viewer', 'viewer.bundle.js');
  assert.ok(bundle.startsWith('/*!'), 'the bundle opens with a legal comment');
  const banner = bundle.slice(0, bundle.indexOf('*/') + 2);
  assert.ok(banner.includes('WORLD LABS TECHNOLOGIES'), 'Spark notice in the bundle');
  assert.ok(banner.includes('three.js authors'), 'three.js notice in the bundle');
  assert.ok(banner.includes('Arjun Barrett'), 'fflate notice in the bundle');
  assert.ok(banner.includes('Permission is hereby granted'), 'the licence text itself is in the bundle');
  assert.ok(banner.includes('THIRD_PARTY_LICENSES.txt'), 'the bundle points at the crate notices');
  // The full set, generated from third_party/licenses by build.mjs, is a Flutter asset the app registers.
  const all = read('assets', 'spatial_viewer', 'THIRD_PARTY_LICENSES.txt');
  for (const file of ['SPARK-MIT.txt', 'THREE-MIT.txt', 'FFLATE-MIT.txt', 'SPARK-WASM-CRATES.txt']) {
    assert.ok(all.includes(read('third_party', 'licenses', file).split(String.fromCharCode(13)).join('').trimEnd()), `${file} is in the asset, verbatim`);
  }
  assert.match(read('pubspec.yaml'), /- assets\/spatial_viewer\/THIRD_PARTY_LICENSES\.txt/);
  assert.match(read('lib', 'main.dart'), /registerSpatialViewerLicenses\(\)/);
  assert.match(read('lib', 'services', 'third_party_licenses.dart'), /LicenseRegistry\.addLicense/);
});
