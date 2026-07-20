import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const gateway = readFileSync(resolve(repoRoot, 'web', 'seo-proxy.php'), 'utf8');

test('gateway upgrades only canonical public detail routes when upstream takeover is absent', () => {
  assert.match(gateway, /function takeoverTargetForPath/);
  assert.match(gateway, /'artworks' => 'artwork'/);
  assert.match(gateway, /'umetnine' => 'artwork'/);
  assert.match(gateway, /'profiles' => 'profile'/);
  assert.match(gateway, /'profili' => 'profile'/);
  assert.match(gateway, /preg_match\('#\^\/\(en\|sl\)\/\(\[\^\/\]\+\)\/\(\[\^\/\]\+\)\/?\$#'/);
  assert.doesNotMatch(gateway, /'artists' =>/);
  assert.doesNotMatch(gateway, /'institutions' =>/);
  assert.doesNotMatch(gateway, /'collectibles' => 'collectible'/);
});

test('gateway preserves SSR and injects the exact Flutter takeover contract', () => {
  assert.match(gateway, /function injectTakeoverShell/);
  assert.match(gateway, /id=\\"public-document\\"/);
  assert.match(gateway, /id=\\"flutter-host\\"/);
  assert.match(gateway, /data-entity-type=\\"/);
  assert.match(gateway, /data-entity-id=\\"/);
  assert.match(gateway, /data-entity-path=\\"/);
  assert.match(gateway, /public_flutter_takeover\.js/);
  assert.match(gateway, /flutter_bootstrap\.js/);
  assert.match(gateway, /accounts\.google\.com\/gsi\/client/);
  assert.match(gateway, /stripos\(\$html, 'id=\\"flutter-host\\"'/);
});

test('gateway applies takeover CSP and invalidates transformed upstream validators', () => {
  assert.match(gateway, /const KUBUS_TAKEOVER_CSP/);
  assert.match(gateway, /'wasm-unsafe-eval'/);
  assert.match(gateway, /\$upstreamHeaders\['content-security-policy'\] = KUBUS_TAKEOVER_CSP/);
  assert.match(gateway, /unset\(\$upstreamHeaders\['etag'\], \$upstreamHeaders\['last-modified'\]\)/);
  assert.match(gateway, /\$status === 200/);
  assert.match(gateway, /\$method === 'GET'/);
});
