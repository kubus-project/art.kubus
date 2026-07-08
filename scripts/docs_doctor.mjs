import { existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const rootDir = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const failures = [];

const requiredFiles = [
  '.gitmodules',
  'AGENTS.md',
  'lib/AGENTS.md',
  'lib/providers/AGENTS.md',
  'lib/screens/AGENTS.md',
  'lib/screens/desktop/AGENTS.md',
  'lib/services/AGENTS.md',
  'backend/AGENTS.md',
  'backend/src/AGENTS.md',
  'backend/src/middleware/AGENTS.md',
  'backend/src/routes/AGENTS.md',
  'backend/src/services/AGENTS.md',
  'docs/README.md',
  'docs/LOCAL_VERIFICATION.md',
  'DESLOPPIFY.md',
];

function absolute(relativePath) {
  return resolve(rootDir, relativePath);
}

function fail(message) {
  failures.push(message);
}

function readText(relativePath) {
  const filePath = absolute(relativePath);
  if (!existsSync(filePath)) {
    fail(`Missing required file: ${relativePath}`);
    return '';
  }
  return readFileSync(filePath, 'utf8');
}

function requireIncludes(relativePath, needles) {
  const text = readText(relativePath);
  for (const needle of needles) {
    if (!text.includes(needle)) {
      fail(`${relativePath} is missing required text: ${needle}`);
    }
  }
}

function checkPackageScripts() {
  const packageJson = JSON.parse(readText('package.json'));
  const scripts = packageJson.scripts || {};
  const requiredScripts = [
    'backend:status',
    'docs:doctor',
    'guard:architecture',
    'qa:web',
    'verify:all',
    'verify:backend',
    'verify:backend-status',
    'verify:docs',
    'verify:flutter',
  ];

  for (const scriptName of requiredScripts) {
    if (!scripts[scriptName]) {
      fail(`package.json is missing script "${scriptName}".`);
    }
  }
}

function checkMarkdownLinks(relativePath) {
  const text = readText(relativePath);
  const linkPattern = /\[[^\]]+\]\(([^)]+)\)/g;
  let match;

  while ((match = linkPattern.exec(text)) !== null) {
    const rawTarget = match[1].trim();
    if (
      rawTarget.startsWith('#') ||
      rawTarget.startsWith('http://') ||
      rawTarget.startsWith('https://') ||
      rawTarget.startsWith('mailto:')
    ) {
      continue;
    }

    const [targetWithoutAnchor] = rawTarget.split('#');
    if (!targetWithoutAnchor) continue;

    const target = decodeURIComponent(targetWithoutAnchor);
    const resolved = resolve(dirname(absolute(relativePath)), target);
    if (!existsSync(resolved)) {
      fail(`${relativePath} has a broken local Markdown link: ${rawTarget}`);
    }
  }
}

function checkMojibake(relativePath) {
  const text = readText(relativePath);
  const suspicious = text.match(/(?:Ã.|Â.|â[\u0080-\u00bf]?)/g);
  if (suspicious) {
    fail(`${relativePath} contains possible mojibake: ${[...new Set(suspicious)].join(', ')}`);
  }
}

function checkArtifactHygiene() {
  requireIncludes('.gitignore', ['/output/playwright/artifacts/']);

  const result = spawnSync('git', ['ls-files', 'output/playwright/artifacts'], {
    cwd: rootDir,
    encoding: 'utf8',
    shell: process.platform === 'win32',
  });
  if (result.status !== 0) {
    fail(`Unable to inspect tracked Playwright artifacts: ${result.stderr || result.error?.message}`);
    return;
  }
  if (result.stdout.trim()) {
    fail(`Playwright generated artifacts are tracked:\n${result.stdout.trim()}`);
  }
}

function checkRequiredFiles() {
  for (const relativePath of requiredFiles) {
    const filePath = absolute(relativePath);
    if (!existsSync(filePath)) {
      fail(`Missing required file: ${relativePath}`);
      continue;
    }
    if (!statSync(filePath).isFile()) {
      fail(`Required path is not a file: ${relativePath}`);
    }
  }
}

checkRequiredFiles();
checkPackageScripts();
checkArtifactHygiene();

requireIncludes('docs/README.md', [
  'LOCAL_VERIFICATION.md',
  '../AGENTS.md',
  '../backend/README.md',
]);
requireIncludes('docs/LOCAL_VERIFICATION.md', [
  'npm run docs:doctor',
  'npm run backend:status',
  'backend-open-art-wt',
  'npm run qa:web',
  'npm run verify:all',
  'FLUTTER_BIN',
  'output/playwright/artifacts/',
]);
requireIncludes('.gitmodules', [
  'path = backend',
  'path = backend-open-art-wt',
  'git@github.com:kubus-project/art.kubus-backend.git',
]);
requireIncludes('AGENTS.md', [
  'StorageConfig.resolveUrl(raw)',
  'publicSyncService',
  'No legacy code paths',
  'flutter analyze passes',
]);
requireIncludes('lib/AGENTS.md', [
  'Provider',
  'StorageConfig.resolveUrl',
  'No widget',
]);
requireIncludes('lib/screens/AGENTS.md', [
  'Theme + tokens',
  'Tutorial overlays',
  'Map web style URL',
]);
requireIncludes('lib/screens/desktop/AGENTS.md', [
  'Maintain feature parity',
  'Travel mode',
  'glass UI tokens',
]);
requireIncludes('backend/AGENTS.md', [
  'publicSyncService',
  'ORBITDB_SYNC_MODE=off',
  'Do not add legacy compatibility layers',
]);
requireIncludes('backend/src/routes/AGENTS.md', [
  'verifyToken',
  'Validation middleware',
  '/health/writable',
]);
requireIncludes('DESLOPPIFY.md', [
  '## Harness engineering alignment',
  '## Suggested cleanup sequence',
  '## Completed tasks',
]);

checkMarkdownLinks('docs/README.md');
checkMarkdownLinks('docs/LOCAL_VERIFICATION.md');

for (const file of requiredFiles.filter((name) => name.endsWith('.md'))) {
  checkMojibake(file);
}

if (failures.length) {
  console.error('Docs doctor found issues:');
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`Docs doctor passed (${requiredFiles.length} required files checked).`);
