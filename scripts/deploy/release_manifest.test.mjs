import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  buildManifest,
  CHECKSUMS_NAME,
  expectedFiles,
  MANIFEST_NAME,
  releaseNotes,
  verifyRelease,
} from './release_manifest.mjs';

const TAG = 'v9.9.9';
const SHA = 'a'.repeat(40);
const VERSION = '9.9.9';

function makeRelease(iosMode, { skip = [], extra = {}, iosRecord } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'release-manifest-'));
  const expected = expectedFiles(TAG, SHA, iosMode);
  const record = iosRecord ?? (iosMode === 'signed'
    ? { tag: TAG, source_sha: SHA, version: VERSION, team_id: 'ABCDE12345' }
    : { source_ref: TAG, source_sha: SHA, version: VERSION, signed: false });
  for (const name of [...expected.android, ...expected.ios]) {
    if (skip.includes(name)) continue;
    writeFileSync(join(dir, name), name.endsWith('.json') ? JSON.stringify(record) : `bytes of ${name}`);
  }
  for (const [name, body] of Object.entries(extra)) writeFileSync(join(dir, name), body);
  return dir;
}

function build(dir, iosMode) {
  return buildManifest({ dir, tag: TAG, sha: SHA, version: VERSION, buildNumber: '2610180001', iosMode });
}

function seal(dir, manifest) {
  writeFileSync(join(dir, MANIFEST_NAME), `${JSON.stringify(manifest)}\n`);
  const lines = [...manifest.files.map((file) => `${file.sha256}  ./${file.name}`)];
  const manifestHash = createHash('sha256').update(`${JSON.stringify(manifest)}\n`).digest('hex');
  lines.push(`${manifestHash}  ./${MANIFEST_NAME}`);
  writeFileSync(join(dir, CHECKSUMS_NAME), `${lines.join('\n')}\n`);
}

test('a complete unsigned release records that its IPA is not distributable', () => {
  const dir = makeRelease('unsigned');
  try {
    const manifest = build(dir, 'unsigned');
    assert.equal(manifest.complete, true);
    assert.deepEqual(manifest.platforms.ios, {
      mode: 'unsigned',
      signed: false,
      distributable: false,
      files: manifest.platforms.ios.files,
    });
    assert.match(manifest.platforms.ios.files[0].name, /-unsigned\.ipa$/);
    assert.match(releaseNotes(manifest), /\*\*UNSIGNED\*\*/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('a complete signed release is distributable and its notes say so', () => {
  const dir = makeRelease('signed');
  try {
    const manifest = build(dir, 'signed');
    assert.equal(manifest.platforms.ios.distributable, true);
    assert.doesNotMatch(releaseNotes(manifest), /UNSIGNED/);
    assert.match(releaseNotes(manifest), /signed for distribution/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('a release without its iOS package is refused, never reported complete', () => {
  const missing = expectedFiles(TAG, SHA, 'unsigned').ios[0];
  const dir = makeRelease('unsigned', { skip: [missing] });
  try {
    assert.throws(() => build(dir, 'unsigned'), new RegExp(`missing release file ${missing.replace(/\./g, '\\.')}`));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('a release without an Android package is refused', () => {
  const missing = expectedFiles(TAG, SHA, 'signed').android[1];
  const dir = makeRelease('signed', { skip: [missing] });
  try {
    assert.throws(() => build(dir, 'signed'), /missing release file .*\.aab/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('stray files and a mismatched iOS mode are refused', () => {
  const stray = makeRelease('unsigned', { extra: { 'notes.txt': 'x' } });
  const wrongMode = makeRelease('unsigned');
  try {
    assert.throws(() => build(stray, 'unsigned'), /unexpected release file notes\.txt/);
    assert.throws(() => build(wrongMode, 'signed'), /missing release file .*\.ipa/);
  } finally {
    rmSync(stray, { recursive: true, force: true });
    rmSync(wrongMode, { recursive: true, force: true });
  }
});

test('the iOS build record must match the tagged source and signing state', () => {
  const wrongSha = makeRelease('unsigned', {
    iosRecord: { source_ref: TAG, source_sha: 'b'.repeat(40), version: VERSION, signed: false },
  });
  const claimsSigned = makeRelease('unsigned', {
    iosRecord: { source_ref: TAG, source_sha: SHA, version: VERSION, signed: true },
  });
  const noTeam = makeRelease('signed', {
    iosRecord: { tag: TAG, source_sha: SHA, version: VERSION },
  });
  try {
    assert.throws(() => build(wrongSha, 'unsigned'), /different source commit/);
    assert.throws(() => build(claimsSigned, 'unsigned'), /signed:false/);
    assert.throws(() => build(noTeam, 'signed'), /signing team/);
  } finally {
    for (const dir of [wrongSha, claimsSigned, noTeam]) rmSync(dir, { recursive: true, force: true });
  }
});

test('verification accepts a sealed release and rejects tampering or drift', () => {
  const dir = makeRelease('unsigned');
  try {
    seal(dir, build(dir, 'unsigned'));
    assert.equal(verifyRelease({ dir, tag: TAG, sha: SHA }).complete, true);

    assert.throws(() => verifyRelease({ dir, tag: 'v9.9.8', sha: SHA }), /different tag or commit/);

    const apk = expectedFiles(TAG, SHA, 'unsigned').android[0];
    writeFileSync(join(dir, apk), 'tampered');
    assert.throws(() => verifyRelease({ dir, tag: TAG, sha: SHA }), new RegExp(`${apk.replace(/\./g, '\\.')} does not match the manifest`));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('verification rejects a checksum file that omits a release file', () => {
  const dir = makeRelease('signed');
  try {
    const manifest = build(dir, 'signed');
    seal(dir, manifest);
    const ipa = expectedFiles(TAG, SHA, 'signed').ios[0];
    writeFileSync(join(dir, CHECKSUMS_NAME), manifest.files.filter((file) => file.name !== ipa).map((file) => `${file.sha256}  ./${file.name}`).join('\n'));
    assert.throws(() => verifyRelease({ dir, tag: TAG, sha: SHA }), /does not match SHA256SUMS/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
