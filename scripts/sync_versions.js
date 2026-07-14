#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');

const rootDir = path.resolve(__dirname, '..');
let manifestPath = path.join(rootDir, 'version.json');

// Parse CLI args for --manifest
const manifestArg = process.argv.find(arg => arg.startsWith('--manifest'));
if (manifestArg) {
  if (manifestArg === '--manifest' && process.argv.includes('--manifest')) {
    const idx = process.argv.indexOf('--manifest');
    if (idx + 1 < process.argv.length) {
      manifestPath = path.resolve(process.argv[idx + 1]);
    }
  } else if (manifestArg.startsWith('--manifest=')) {
    manifestPath = path.resolve(manifestArg.slice(11));
  }
}

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

  // Allow date-like dotted build numbers (e.g. "20260512.02") by flattening.
  if (/^\d+(\.\d+)+$/.test(text)) {
    const flattened = text.replace(/\./g, '');
    const parsed = Number.parseInt(flattened, 10);
    if (Number.isSafeInteger(parsed) && parsed >= 0) {
      return parsed;
    }
  }

  throw new Error(
    'buildNumber must be a non-negative integer (e.g. 42) or numeric string (e.g. "42" or "20260512.02")',
  );
}

function replaceOrThrow(source, matcher, replacement, description) {
  const hasMatch = matcher.test(source);
  if (!hasMatch) {
    throw new Error(`Failed to update ${description}`);
  }
  return source.replace(matcher, replacement);
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
    /static const String version\s*=\s*(?:String\.fromEnvironment\(\s*'KUBUS_APP_VERSION',\s*defaultValue:\s*'[^']+',\s*\)|'[^']+');/,
    `static const String version = String.fromEnvironment(
    'KUBUS_APP_VERSION',
    defaultValue: '${version}',
  );`,
    'AppInfo.version',
  );
  raw = replaceOrThrow(
    raw,
    /static const int buildNumber\s*=\s*(?:int\.fromEnvironment\(\s*'KUBUS_BUILD_NUMBER',\s*defaultValue:\s*\d+,\s*\)|\d+);/,
    `static const int buildNumber = int.fromEnvironment(
    'KUBUS_BUILD_NUMBER',
    defaultValue: ${buildNumber},
  );`,
    'AppInfo.buildNumber',
  );
  raw = replaceOrThrow(
    raw,
    /static const String buildDate\s*=\s*(?:String\.fromEnvironment\(\s*'KUBUS_BUILD_DATE',\s*defaultValue:\s*'[^']+',\s*\)|'[^']+');/,
    `static const String buildDate = String.fromEnvironment(
    'KUBUS_BUILD_DATE',
    defaultValue: '${buildDate}',
  );`,
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

  syncPubspec(manifest.version, normalizedBuildNumber);
  syncAppConfig(manifest.version, normalizedBuildNumber, manifest.buildDate);

  process.stdout.write(
    `Synced versions to ${manifest.version}+${normalizedBuildNumber} (${manifest.buildDate})\n`,
  );
}

run();
