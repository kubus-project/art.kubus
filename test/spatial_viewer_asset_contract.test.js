// Contract for the bundled spatial viewer asset and the CSP it runs under on the web.
// Run with: node --test test/spatial_viewer_asset_contract.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

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
