#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const rootDir = path.resolve(__dirname, '..');
const manifestPath = path.join(rootDir, 'version.json');

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeText(filePath, content) {
  fs.writeFileSync(filePath, content, 'utf8');
}

function normalizeBuildNumber(rawBuildNumber) {
  if (Number.isInteger(rawBuildNumber) && rawBuildNumber >= 0) {
    return rawBuildNumber;
  }

  const text = String(rawBuildNumber ?? '').trim();
  if (/^\d+$/.test(text)) {
    const parsed = Number.parseInt(text, 10);
    if (Number.isSafeInteger(parsed) && parsed >= 0) {
      return parsed;
    }
  }

  // Allow date-like dotted build numbers (e.g. "20260325.1") by flattening.
  if (/^\d+(\.\d+)+$/.test(text)) {
    const flattened = text.replace(/\./g, '');
    const parsed = Number.parseInt(flattened, 10);
    if (Number.isSafeInteger(parsed) && parsed >= 0) {
      return parsed;
    }
  }

  throw new Error(
    'buildNumber must be a non-negative integer (e.g. 42) or numeric string (e.g. "42" or "20260325.1")',
  );
}

function replaceOrThrow(source, matcher, replacement, description) {
  const hasMatch = matcher.test(source);
  if (!hasMatch) {
    throw new Error(`Failed to update ${description}`);
  }
  return source.replace(matcher, replacement);
}

function syncBackendPackage(version) {
  const filePath = path.join(rootDir, 'backend', 'package.json');
  const data = readJson(filePath);
  data.version = version;
  writeText(filePath, `${JSON.stringify(data, null, 2)}\n`);
}

function syncPubspec(version, buildNumber) {
  const filePath = path.join(rootDir, 'pubspec.yaml');
  const raw = fs.readFileSync(filePath, 'utf8');
  const updated = replaceOrThrow(
    raw,
    /^version:\s*[^\r\n]+/m,
    `version: ${version}+${buildNumber}`,
    'pubspec.yaml version',
  );
  writeText(filePath, updated);
}

function syncAppConfig(version, buildNumber, buildDate) {
  const filePath = path.join(rootDir, 'lib', 'config', 'config.dart');
  let raw = fs.readFileSync(filePath, 'utf8');

  raw = replaceOrThrow(
    raw,
    /static const String version\s*=\s*['"][^'"]+['"];/,
    `static const String version = '${version}';`,
    'AppInfo.version',
  );
  raw = replaceOrThrow(
    raw,
    /static const int buildNumber\s*=\s*\d+;/,
    `static const int buildNumber = ${buildNumber};`,
    'AppInfo.buildNumber',
  );
  raw = replaceOrThrow(
    raw,
    /static const String buildDate\s*=\s*['"][^'"]+['"];/,
    `static const String buildDate = '${buildDate}';`,
    'AppInfo.buildDate',
  );

  writeText(filePath, raw);
}

function validateManifest(manifest) {
  if (!manifest || typeof manifest !== 'object') {
    throw new Error('version.json must be a JSON object');
  }
  const { version, buildNumber, buildDate } = manifest;
  if (!/^\d+\.\d+\.\d+$/.test(String(version || ''))) {
    throw new Error('version must use semantic format X.Y.Z');
  }
  normalizeBuildNumber(buildNumber);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(buildDate || ''))) {
    throw new Error('buildDate must use YYYY-MM-DD format');
  }
}

function run() {
  const manifest = readJson(manifestPath);
  validateManifest(manifest);
  const normalizedBuildNumber = normalizeBuildNumber(manifest.buildNumber);

  syncBackendPackage(manifest.version);
  syncPubspec(manifest.version, normalizedBuildNumber);
  syncAppConfig(manifest.version, normalizedBuildNumber, manifest.buildDate);

  process.stdout.write(
    `Synced versions to ${manifest.version}+${normalizedBuildNumber} (${manifest.buildDate})\n`,
  );
}

run();
