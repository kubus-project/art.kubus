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
  '.github/copilot-instructions.md',
  'CONTRIBUTING.md',
  'docs/README.md',
  'docs/LOCAL_VERIFICATION.md',
  'docs/engineering/branching-and-deployment.md',
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
    'qa:web:test',
    'verify:all',
    'verify:architecture',
    'verify:backend',
    'verify:backend-status',
    'verify:ci',
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
    const backendRoot = absolute('backend');
    if (!existsSync(resolved) && (resolved === backendRoot || resolved.startsWith(`${backendRoot}${process.platform === 'win32' ? '\\' : '/'}`))) {
      // The private backend is a validated gitlink. Unprivileged PR jobs do not
      // materialize it, so its internal documentation links are checked by the
      // trusted scheduled/backend workflows instead.
      continue;
    }
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
  'engineering/branching-and-deployment.md',
  '../AGENTS.md',
  '../backend/README.md',
]);
requireIncludes('docs/LOCAL_VERIFICATION.md', [
  'npm run docs:doctor',
  'npm run backend:status',
  'backend-open-art-wt',
  'npm run qa:web',
  'npm run verify:all',
  'npm run verify:ci',
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
  'master` is production-only',
  'origin/dev',
  'docs/engineering/branching-and-deployment.md',
]);
requireIncludes('lib/AGENTS.md', [
  'Provider',
  'StorageConfig.resolveUrl',
  'No widget',
  '## Branch governance',
  'origin/dev',
]);
requireIncludes('lib/screens/AGENTS.md', [
  'Theme + tokens',
  'Tutorial overlays',
  'Map web style URL',
  '## Branch governance',
]);
requireIncludes('lib/screens/desktop/AGENTS.md', [
  'Maintain feature parity',
  'Travel mode',
  'glass UI tokens',
  '## Branch governance',
]);
requireIncludes('lib/providers/AGENTS.md', ['## Branch governance', 'origin/dev']);
requireIncludes('lib/services/AGENTS.md', ['## Branch governance', 'origin/dev']);
requireIncludes('.github/copilot-instructions.md', ['origin/dev', 'branching-and-deployment.md']);
requireIncludes('CONTRIBUTING.md', ['origin/dev', 'targeting `dev`', 'hotfix/*']);
requireIncludes('docs/engineering/branching-and-deployment.md', [
  '`master` is production-only',
  '`dev` is the integration branch',
  'development-web',
  'production-web',
  'PR validation required',
  'hotfix',
]);
requireIncludes('DESLOPPIFY.md', [
  '## Harness engineering alignment',
  '## Suggested cleanup sequence',
  '## Completed tasks',
]);

checkMarkdownLinks('docs/README.md');
checkMarkdownLinks('docs/LOCAL_VERIFICATION.md');
checkMarkdownLinks('docs/engineering/branching-and-deployment.md');
checkMarkdownLinks('CONTRIBUTING.md');

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
