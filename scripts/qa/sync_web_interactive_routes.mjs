#!/usr/bin/env node
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const manifestPath = resolve(repoRoot, 'web', 'web_interactive_routes.json');
const htaccessPath = resolve(repoRoot, 'web', '.htaccess');
const begin = '  # BEGIN GENERATED WEB INTERACTIVE ROUTES';
const end = '  # END GENERATED WEB INTERACTIVE ROUTES';

function escapeApacheRegex(value) {
  return value.replace(/[\\^$.*+?()[\]{}|]/g, '\\$&');
}

function validateManifest(manifest) {
  if (manifest.schemaVersion !== 1 || !Array.isArray(manifest.routes)) {
    throw new Error('web route manifest must use schemaVersion 1 and contain routes[]');
  }
  const seenPaths = new Set();
  const seenTests = new Set();
  for (const route of manifest.routes) {
    if (!['root', 'locale-root', 'app-prefix', 'finite'].includes(route.group)) {
      throw new Error(`unsupported route group for ${route.path}`);
    }
    if (typeof route.path !== 'string' || !route.path.startsWith('/')) {
      throw new Error(`route path must be an absolute path: ${route.path}`);
    }
    if (route.path.includes('?') || route.path.includes('#')) {
      throw new Error(`route path must not contain query or fragment: ${route.path}`);
    }
    if (typeof route.testUrl !== 'string' || !route.testUrl.startsWith('/')) {
      throw new Error(`route testUrl must be root-relative: ${route.path}`);
    }
    if (seenPaths.has(route.path)) throw new Error(`duplicate route path: ${route.path}`);
    if (seenTests.has(route.testUrl)) throw new Error(`duplicate route testUrl: ${route.testUrl}`);
    seenPaths.add(route.path);
    seenTests.add(route.testUrl);
  }
  for (const required of ['/', '/en', '/sl', '/app', '/app/*', '/onboarding', '/register']) {
    if (!seenPaths.has(required)) throw new Error(`required browser route is missing: ${required}`);
  }
}

function generatedBlock(manifest) {
  const alternatives = manifest.routes
    .filter((route) => route.group === 'finite')
    .map((route) => route.path.slice(1))
    .sort((a, b) => a.localeCompare(b))
    .map(escapeApacheRegex);
  if (alternatives.length === 0) throw new Error('finite browser route set must not be empty');
  return [
    begin,
    '  # Generated from web/web_interactive_routes.json. Do not edit this rule by hand.',
    '  RewriteCond %{REQUEST_FILENAME} !-f',
    '  RewriteCond %{REQUEST_FILENAME} !-d',
    `  RewriteRule ^(?:${alternatives.join('|')})/?$ index.html [L]`,
    end,
  ].join('\n');
}

const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
validateManifest(manifest);
const htaccess = await readFile(htaccessPath, 'utf8');
const start = htaccess.indexOf(begin);
const finish = htaccess.indexOf(end);
if (start === -1 || finish === -1 || finish < start) {
  throw new Error('generated route markers are missing or out of order in web/.htaccess');
}
const after = finish + end.length;
const expected = `${htaccess.slice(0, start)}${generatedBlock(manifest)}${htaccess.slice(after)}`;

if (process.argv.includes('--check')) {
  if (expected !== htaccess) {
    console.error('web/.htaccess interactive route rule is stale; run: node scripts/qa/sync_web_interactive_routes.mjs');
    process.exit(1);
  }
  console.log(`web route manifest is synchronized (${manifest.routes.length} refresh checks)`);
} else {
  await writeFile(htaccessPath, expected);
  console.log(`updated web/.htaccess from ${manifest.routes.length} canonical refresh routes`);
}
