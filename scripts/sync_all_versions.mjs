#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const stackDir = path.resolve(__dirname, '..');
const manifestPath = path.join(stackDir, 'version.json');

// ===== Helpers =====

function readJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (err) {
    throw new Error(`Failed to read JSON from ${filePath}: ${err.message}`);
  }
}

function writeText(filePath, content) {
  fs.writeFileSync(filePath, content, 'utf8');
}

function writeJsonIfChanged(filePath, data, changes) {
  const nextContent = JSON.stringify(data, null, 2) + '\n';
  writeIfChanged(filePath, nextContent, changes);
}

function writeIfChanged(filePath, nextContent, changes) {
  let currentContent = '';
  try {
    currentContent = fs.readFileSync(filePath, 'utf8');
  } catch {
    // File doesn't exist yet
  }

  if (currentContent === nextContent) {
    return;
  }

  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  writeText(filePath, nextContent);
  changes.push(filePath);
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
    'buildNumber must be a non-negative integer (e.g. 42) or numeric string (e.g. "42" or "20260512.02")'
  );
}

function validateManifest(manifest) {
  if (!manifest || typeof manifest !== 'object') {
    throw new Error('version.json must be a JSON object');
  }

  const { version, buildNumber, buildDate, targets } = manifest;

  if (!version || !/^\d+\.\d+\.\d+$/.test(version)) {
    throw new Error(`Invalid version: ${version}. Must be X.Y.Z`);
  }

  if (buildNumber === undefined) {
    throw new Error('buildNumber is required');
  }

  // Normalize and validate buildNumber
  try {
    normalizeBuildNumber(buildNumber);
  } catch (err) {
    throw new Error(`Invalid buildNumber: ${err.message}`);
  }

  if (!buildDate || !/^\d{4}-\d{2}-\d{2}$/.test(buildDate)) {
    throw new Error(`Invalid buildDate: ${buildDate}. Must be YYYY-MM-DD`);
  }

  if (!targets || typeof targets !== 'object' || Object.keys(targets).length === 0) {
    throw new Error('targets must be a non-empty object');
  }

  for (const [key, target] of Object.entries(targets)) {
    if (!target.repo || !target.path || !target.kind) {
      throw new Error(`Target '${key}' missing required fields: repo, path, kind`);
    }
  }
}

function replaceOrThrow(source, matcher, replacement, description) {
  if (!matcher.test(source)) {
    throw new Error(`Failed to update ${description}: pattern not found`);
  }
  return source.replace(matcher, replacement);
}

// ===== Sync Functions =====

function syncPackageJson(repoDir, manifest, changes) {
  const filePath = path.join(repoDir, 'package.json');
  if (!fs.existsSync(filePath)) {
    return;
  }

  const data = readJson(filePath);
  data.version = manifest.version;

  // Ensure sync scripts exist
  if (!data.scripts) {
    data.scripts = {};
  }
  data.scripts['sync:version'] = data.scripts['sync:version'] || 'node scripts/sync_version.js';
  data.scripts['sync:versions'] = 'npm run sync:version';

  writeJsonIfChanged(filePath, data, changes);
}

function syncPackageLock(repoDir, manifest, changes) {
  const filePath = path.join(repoDir, 'package-lock.json');
  if (!fs.existsSync(filePath)) {
    return;
  }

  const data = readJson(filePath);
  const hadChanges = data.version !== manifest.version;

  if (data.version !== manifest.version) {
    data.version = manifest.version;
  }

  // Also update packages[""] if it exists
  if (data.packages && data.packages[''] && data.packages[''].version !== manifest.version) {
    data.packages[''].version = manifest.version;
  }

  if (!hadChanges && (!data.packages || !data.packages[''] || data.packages[''].version === manifest.version)) {
    return;
  }

  writeJsonIfChanged(filePath, data, changes);
}

function syncLocalVersionJson(repoDir, manifest, changes) {
  const filePath = path.join(repoDir, 'version.json');
  const localData = {
    version: manifest.version,
    buildNumber: manifest.buildNumber,
    buildDate: manifest.buildDate,
    channel: manifest.channel || 'beta',
  };

  writeJsonIfChanged(filePath, localData, changes);
}

function syncVersionTs(repoDir, manifest, changes) {
  const filePath = path.join(repoDir, 'src', 'version.ts');
  if (!fs.existsSync(filePath)) {
    return;
  }

  const numericBuildNumber = normalizeBuildNumber(manifest.buildNumber);
  const content = `export const KUBUS_VERSION = '${manifest.version}'
export const KUBUS_BUILD_NUMBER = '${manifest.buildNumber}'
export const KUBUS_BUILD_NUMBER_NUMERIC = ${numericBuildNumber}
export const KUBUS_BUILD_DATE = '${manifest.buildDate}'
export const KUBUS_CHANNEL = '${manifest.channel || 'beta'}'
`;

  writeIfChanged(filePath, content, changes);
}

function syncBackendVersionJs(repoDir, manifest, changes) {
  const filePath = path.join(repoDir, 'src', 'config', 'version.js');
  if (!fs.existsSync(path.dirname(filePath))) {
    return;
  }

  const numericBuildNumber = normalizeBuildNumber(manifest.buildNumber);
  const content = `module.exports = {
  version: '${manifest.version}',
  buildNumber: '${manifest.buildNumber}',
  buildNumberNumeric: ${numericBuildNumber},
  buildDate: '${manifest.buildDate}',
  channel: '${manifest.channel || 'beta'}'
};
`;

  writeIfChanged(filePath, content, changes);
}

function syncFlutterRepo(repoDir, manifest, changes) {
  // pubspec.yaml
  const pubspecPath = path.join(repoDir, 'pubspec.yaml');
  if (fs.existsSync(pubspecPath)) {
    let raw = fs.readFileSync(pubspecPath, 'utf8');
    const numericBuildNumber = normalizeBuildNumber(manifest.buildNumber);
    raw = replaceOrThrow(
      raw,
      /^version:\s*[^\r\n]+/m,
      `version: ${manifest.version}+${numericBuildNumber}`,
      'pubspec.yaml version'
    );
    writeIfChanged(pubspecPath, raw, changes);
  }

  // lib/config/config.dart
  const configPath = path.join(repoDir, 'lib', 'config', 'config.dart');
  if (fs.existsSync(configPath)) {
    let raw = fs.readFileSync(configPath, 'utf8');
    const numericBuildNumber = normalizeBuildNumber(manifest.buildNumber);

    raw = replaceOrThrow(
      raw,
      /static const String version\s*=\s*['"][^'"]+['"];/,
      `static const String version = '${manifest.version}';`,
      'AppInfo.version'
    );
    raw = replaceOrThrow(
      raw,
      /static const int buildNumber\s*=\s*\d+;/,
      `static const int buildNumber = ${numericBuildNumber};`,
      'AppInfo.buildNumber'
    );
    raw = replaceOrThrow(
      raw,
      /static const String buildDate\s*=\s*['"][^'"]+['"];/,
      `static const String buildDate = '${manifest.buildDate}';`,
      'AppInfo.buildDate'
    );

    writeIfChanged(configPath, raw, changes);
  }

  // Sync package.json and local version.json for Flutter repo
  syncPackageJson(repoDir, manifest, changes);
  syncPackageLock(repoDir, manifest, changes);
  syncLocalVersionJson(repoDir, manifest, changes);
}

function syncNodeLikeRepo(repoDir, manifest, targetKind, changes) {
  syncPackageJson(repoDir, manifest, changes);
  syncPackageLock(repoDir, manifest, changes);
  syncLocalVersionJson(repoDir, manifest, changes);

  if (targetKind === 'node' || targetKind === 'vite' || targetKind === 'backend-node') {
    syncVersionTs(repoDir, manifest, changes);
  }

  if (targetKind === 'backend-node') {
    syncBackendVersionJs(repoDir, manifest, changes);
  }
}

// ===== Main =====

function main() {
  const args = process.argv.slice(2);
  let mode = 'sync'; // 'sync', 'check', or 'target'
  let targetName = null;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--check') {
      mode = 'check';
    } else if (arg === '--target') {
      mode = 'target';
      if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        targetName = args[i + 1];
        i++;
      }
    } else if (arg.startsWith('--target=')) {
      mode = 'target';
      targetName = arg.slice(9);
    }
  }

  if (mode === 'target' && !targetName) {
    console.error('Error: --target requires a target name (e.g., --target frontend)');
    process.exit(1);
  }

  // Read manifest
  let manifest;
  try {
    manifest = readJson(manifestPath);
    validateManifest(manifest);
  } catch (err) {
    console.error(`Error reading manifest: ${err.message}`);
    process.exit(1);
  }

  const changes = [];

  // Determine which targets to sync
  const targetsToSync = mode === 'target' ? [targetName] : Object.keys(manifest.targets);

  for (const name of targetsToSync) {
    const target = manifest.targets[name];

    if (!target) {
      console.error(`Unknown target: ${name}`);
      process.exit(1);
    }

    const repoDir = path.resolve(stackDir, target.path);

    // Verify repo exists
    if (!fs.existsSync(repoDir)) {
      console.error(`Target repo not found: ${repoDir} (for target '${name}')`);
      process.exit(1);
    }

    try {
      if (target.kind === 'flutter') {
        syncFlutterRepo(repoDir, manifest, changes);
      } else {
        syncNodeLikeRepo(repoDir, manifest, target.kind, changes);
      }
    } catch (err) {
      console.error(`Error syncing target '${name}': ${err.message}`);
      process.exit(1);
    }
  }

  // Report
  if (mode === 'check') {
    if (changes.length === 0) {
      console.log('✓ All versions in sync');
      process.exit(0);
    } else {
      console.log('✗ Version drift detected:');
      for (const file of changes) {
        console.log(`  ${path.relative(stackDir, file)}`);
      }
      process.exit(1);
    }
  } else {
    if (changes.length === 0) {
      console.log('✓ Already in sync');
      process.exit(0);
    } else {
      console.log(`✓ Updated ${changes.length} file(s):`);
      for (const file of changes) {
        console.log(`  ${path.relative(stackDir, file)}`);
      }
      process.exit(0);
    }
  }
}

main();
