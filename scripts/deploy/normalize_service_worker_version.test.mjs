import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { deterministicServiceWorkerVersion, normalizeServiceWorkerVersion } from './normalize_service_worker_version.mjs';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const SHA = '0123456789abcdef0123456789abcdef01234567';
const NOTICE = "/* Flutter's service worker is deprecated and will be removed in a future Flutter release. */";

// Mirrors what `flutter build web` writes: the random value is substituted into the bootstrap
// declaration and into the index.html template (including the explanatory comment).
function makeBuild(randomVersion, { extra = {} } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'kubus-sw-version-'));
  const declaration = `"${randomVersion}" ${NOTICE}`;
  writeFileSync(join(dir, 'flutter_bootstrap.js'), `const flutterServiceWorkerVersion = ${declaration};\nbootstrap();\n`);
  writeFileSync(join(dir, 'index.html'), [
    '<html><script>',
    `// \`${declaration}\` is replaced during \`flutter build web\`.`,
    `var raw = String.raw\`${declaration}\`;`,
    '</script></html>',
    '',
  ].join('\n'));
  writeFileSync(join(dir, 'main.dart.js'), 'compiled();\n');
  writeFileSync(join(dir, '.htaccess'), '<IfModule mod_rewrite.c>\nRewriteEngine On\n</IfModule>\n');
  for (const [name, content] of Object.entries(extra)) {
    mkdirSync(dirname(join(dir, name)), { recursive: true });
    writeFileSync(join(dir, name), content);
  }
  return dir;
}

function prepare(dir) {
  return execFileSync(process.execPath, [
    join(scriptDir, 'prepare_web_artifact.mjs'),
    '--environment', 'production', '--source-sha', SHA, '--directory', dir,
  ], { encoding: 'utf8' });
}

function manifest(dir) {
  const walk = (directory) => readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    return statSync(path).isDirectory() ? walk(path) : [path];
  });
  return walk(dir).sort().map((file) => `${createHash('sha256').update(readFileSync(file)).digest('hex')}  ${file.slice(dir.length)}`).join('\n');
}

test('the derived version has the shape of Flutter\'s value and follows the commit', () => {
  const version = deterministicServiceWorkerVersion(SHA);
  assert.match(version, /^\d{1,10}$/);
  assert.ok(Number(version) < 2 ** 32);
  assert.equal(version, deterministicServiceWorkerVersion(SHA));
  assert.notEqual(version, deterministicServiceWorkerVersion('f'.repeat(40)));
  assert.throws(() => deterministicServiceWorkerVersion('not-a-sha'), /40 lowercase hex/);
});

test('two builds of one commit with different random versions seal to identical bytes', () => {
  const first = makeBuild('4107033965');
  const second = makeBuild('1553604078');
  try {
    assert.notEqual(manifest(first), manifest(second));
    prepare(first);
    prepare(second);
    assert.equal(manifest(first), manifest(second));
    const expected = deterministicServiceWorkerVersion(SHA);
    assert.match(readFileSync(join(first, 'flutter_bootstrap.js'), 'utf8'), new RegExp(`flutterServiceWorkerVersion = "${expected}"`));
    const index = readFileSync(join(first, 'index.html'), 'utf8');
    assert.equal(index.split(`"${expected}"`).length - 1, 2);
    assert.doesNotMatch(index, /4107033965/);
  } finally {
    rmSync(first, { recursive: true, force: true });
    rmSync(second, { recursive: true, force: true });
  }
});

test('different commits still produce different service worker versions', () => {
  const dir = makeBuild('4107033965');
  try {
    const result = normalizeServiceWorkerVersion(dir, 'f'.repeat(40));
    assert.equal(result.original, '4107033965');
    assert.equal(result.replacement, deterministicServiceWorkerVersion('f'.repeat(40)));
    assert.notEqual(result.replacement, deterministicServiceWorkerVersion(SHA));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('normalization is idempotent', () => {
  const dir = makeBuild('4107033965');
  try {
    prepare(dir);
    const once = manifest(dir);
    prepare(dir);
    assert.equal(manifest(dir), once);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('a volatile value found in any other file fails closed instead of shipping', () => {
  const dir = makeBuild('4107033965', { extra: { 'other.js': 'const v = "4107033965";\n' } });
  try {
    assert.throws(() => prepare(dir), /outside the rewritten files/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('a bootstrap with two declarations is rejected', () => {
  const dir = makeBuild('4107033965');
  try {
    writeFileSync(join(dir, 'flutter_bootstrap.js'), 'const flutterServiceWorkerVersion = "1";\nconst flutterServiceWorkerVersion = "2";\n');
    assert.throws(() => normalizeServiceWorkerVersion(dir, SHA), /exactly one service worker version/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('a build without a service worker version is left untouched', () => {
  const dir = mkdtempSync(join(tmpdir(), 'kubus-sw-none-'));
  try {
    writeFileSync(join(dir, 'flutter_bootstrap.js'), 'bootstrap();\n');
    writeFileSync(join(dir, 'index.html'), '<html></html>');
    const before = manifest(dir);
    assert.equal(normalizeServiceWorkerVersion(dir, SHA), null);
    assert.equal(manifest(dir), before);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
