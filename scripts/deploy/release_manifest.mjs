#!/usr/bin/env node
// Completeness gate for a multi-platform mobile release.
//
//   release_manifest.mjs build  --dir D --tag T --sha S --version V --build-number N --ios-mode signed|unsigned [--notes-out F]
//   release_manifest.mjs verify --dir D --tag T --sha S
//
// `build` accepts exactly the expected Android and iOS files for the tag and
// commit, refuses a missing or stray file, and writes release-manifest.json
// (hashes, sizes, and whether the IPA is signed). `verify` re-checks that
// manifest against the files and SHA256SUMS, also after publication. A release
// that lacks a platform therefore cannot be described as complete.
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

export const MANIFEST_NAME = 'release-manifest.json';
export const CHECKSUMS_NAME = 'SHA256SUMS';
const SHA256 = /^[0-9a-f]{64}$/;

export function expectedFiles(tag, sha, iosMode) {
  const base = `art.kubus-${tag}-${sha}`;
  const android = [`${base}.apk`, `${base}.aab`];
  if (iosMode === 'signed') return { android, ios: [`${base}.ipa`, `${base}.ios-build.json`] };
  if (iosMode === 'unsigned') return { android, ios: [`${base}-unsigned.ipa`, `${base}-unsigned.ios-build.json`] };
  throw new Error(`ios mode must be signed or unsigned (got ${iosMode}).`);
}

export function describeDirectory(dir) {
  return readdirSync(dir)
    .filter((name) => statSync(join(dir, name)).isFile())
    .sort()
    .map((name) => {
      const bytes = readFileSync(join(dir, name));
      return { name, size: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') };
    });
}

function readJson(dir, name) {
  try {
    return JSON.parse(readFileSync(join(dir, name), 'utf8'));
  } catch (error) {
    throw new Error(`${name} is not valid JSON: ${error.message}`);
  }
}

function checkIosBuildRecord(record, { sha, version, iosMode }) {
  const problems = [];
  if (record.source_sha !== sha) problems.push('iOS build record names a different source commit');
  if (record.version !== version) problems.push('iOS build record names a different version');
  if (iosMode === 'unsigned' && record.signed !== false) problems.push('unsigned iOS build record must say signed:false');
  if (iosMode === 'signed' && (record.signed === false || !record.team_id)) {
    problems.push('signed iOS build record must carry the signing team');
  }
  return problems;
}

export function buildManifest({ dir, tag, sha, version, buildNumber, iosMode }) {
  const expected = expectedFiles(tag, sha, iosMode);
  const wanted = new Set([...expected.android, ...expected.ios]);
  const present = describeDirectory(dir).filter((file) => file.name !== MANIFEST_NAME && file.name !== CHECKSUMS_NAME);
  const problems = [];
  for (const name of wanted) {
    if (!present.some((file) => file.name === name)) problems.push(`missing release file ${name}`);
  }
  for (const file of present) {
    if (!wanted.has(file.name)) problems.push(`unexpected release file ${file.name}`);
  }
  if (problems.length === 0) {
    const record = readJson(dir, expected.ios[1]);
    problems.push(...checkIosBuildRecord(record, { sha, version, iosMode }));
  }
  if (problems.length > 0) throw new Error(`Release is not complete:\n- ${problems.join('\n- ')}`);

  const byName = new Map(present.map((file) => [file.name, file]));
  const entries = (names) => names.map((name) => byName.get(name));
  return {
    schema: 1,
    tag,
    sourceSha: sha,
    version,
    buildNumber: String(buildNumber),
    complete: true,
    platforms: {
      android: { signed: true, files: entries(expected.android) },
      ios: {
        mode: iosMode,
        signed: iosMode === 'signed',
        // An unsigned IPA only installs after re-signing by the installer.
        distributable: iosMode === 'signed',
        files: entries(expected.ios),
      },
    },
    files: present,
  };
}

export function releaseNotes(manifest) {
  const ios = manifest.platforms.ios;
  const ipa = ios.files[0].name;
  const lines = [
    `## Platform packages for ${manifest.tag}`,
    '',
    `Source commit \`${manifest.sourceSha}\`, version ${manifest.version} (build ${manifest.buildNumber}). Verify downloads against \`SHA256SUMS\`; \`${MANIFEST_NAME}\` records each file's hash and signing state.`,
    '',
    '- **Android** APK and AAB, signed with the release keystore.',
  ];
  lines.push(
    ios.signed
      ? `- **iOS** \`${ipa}\`, signed for distribution (see \`${ios.files[1].name}\` for the team and export method).`
      : `- **iOS** \`${ipa}\` is **UNSIGNED**. It is not an App Store or TestFlight build and installs only after re-signing, for example with Sideloadly or AltStore using your own Apple ID (a free Apple ID's install expires after 7 days).`,
  );
  return `${lines.join('\n')}\n`;
}

function parseChecksums(text) {
  const entries = new Map();
  for (const line of text.split(/\r?\n/).filter(Boolean)) {
    const match = /^([0-9a-f]{64}) [ *](?:\.\/)?(.+)$/.exec(line);
    if (!match) throw new Error(`Malformed ${CHECKSUMS_NAME} line: ${line}`);
    entries.set(match[2], match[1]);
  }
  return entries;
}

export function verifyRelease({ dir, tag, sha }) {
  const manifest = readJson(dir, MANIFEST_NAME);
  const problems = [];
  if (manifest.schema !== 1 || manifest.complete !== true) problems.push('manifest is not a complete schema-1 manifest');
  if (manifest.tag !== tag || manifest.sourceSha !== sha) problems.push('manifest belongs to a different tag or commit');
  const mode = manifest.platforms?.ios?.mode;
  if (mode !== 'signed' && mode !== 'unsigned') problems.push('manifest has no iOS package');
  if (problems.length === 0) {
    const expected = expectedFiles(tag, sha, mode);
    const named = new Set([...expected.android, ...expected.ios]);
    const onDisk = new Map(describeDirectory(dir).map((file) => [file.name, file]));
    const sums = parseChecksums(readFileSync(join(dir, CHECKSUMS_NAME), 'utf8'));
    for (const file of manifest.files ?? []) {
      if (!SHA256.test(file.sha256)) problems.push(`${file.name} has a malformed hash`);
      if (!named.has(file.name)) problems.push(`${file.name} is not an expected release file`);
      if (onDisk.get(file.name)?.sha256 !== file.sha256) problems.push(`${file.name} does not match the manifest`);
      if (sums.get(file.name) !== file.sha256) problems.push(`${file.name} does not match ${CHECKSUMS_NAME}`);
    }
    for (const name of named) {
      if (!(manifest.files ?? []).some((file) => file.name === name)) problems.push(`${name} is absent from the manifest`);
    }
    if (!sums.has(MANIFEST_NAME)) problems.push(`${CHECKSUMS_NAME} does not cover ${MANIFEST_NAME}`);
    for (const name of onDisk.keys()) {
      if (name !== CHECKSUMS_NAME && !sums.has(name)) problems.push(`${name} is not listed in ${CHECKSUMS_NAME}`);
    }
  }
  if (problems.length > 0) throw new Error(`Release verification failed:\n- ${problems.join('\n- ')}`);
  return manifest;
}

function argument(name) {
  const index = process.argv.indexOf(`--${name}`);
  const value = index >= 0 ? process.argv[index + 1] : undefined;
  if (!value) throw new Error(`Missing --${name}`);
  return value;
}

function main() {
  const command = process.argv[2];
  const dir = resolve(argument('dir'));
  const tag = argument('tag');
  const sha = argument('sha');
  if (command === 'build') {
    const manifest = buildManifest({
      dir,
      tag,
      sha,
      version: argument('version'),
      buildNumber: argument('build-number'),
      iosMode: argument('ios-mode'),
    });
    writeFileSync(join(dir, MANIFEST_NAME), `${JSON.stringify(manifest, null, 2)}\n`);
    if (process.argv.includes('--notes-out')) writeFileSync(resolve(argument('notes-out')), releaseNotes(manifest));
    console.log(`Release manifest written: android + ios (${manifest.platforms.ios.mode}), ${manifest.files.length} files.`);
  } else if (command === 'verify') {
    const manifest = verifyRelease({ dir, tag, sha });
    console.log(`Release ${tag} verified: android + ios (${manifest.platforms.ios.mode}), ${manifest.files.length} files.`);
  } else {
    throw new Error('Usage: release_manifest.mjs build|verify --dir D --tag T --sha S');
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(`::error::${error.message.split('\n').join('%0A')}`);
    process.exit(1);
  }
}
