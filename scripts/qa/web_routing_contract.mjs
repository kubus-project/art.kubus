#!/usr/bin/env node
// Apache rewrite contract for web/.htaccess.
//
// Runs against a real Apache serving web/ with AllowOverride All. mod_rewrite
// behaviour cannot be inferred by reading the file: rule order, [L] termination
// and the bare-locale-versus-deeper-path split all interact, and only execution
// proves the routing is right.
//
// Architecture: /, /en, /sl and /app boot the Flutter application directly (the
// app shell is served from index.html and stays indexable). Deeper localized
// public routes (/en/artworks/:id, /sl/umetnine/:id) hand off to the SEO
// renderer via seo-proxy.php and must NOT leak the app shell. Unknown paths are
// real 404s.
//
// PHP is not required: every assertion here concerns static routing decided
// before (or at) the seo-proxy.php handoff. Without a PHP module Apache serves
// the raw seo-proxy.php file, which is enough to prove the deeper localized
// routes are rewritten away from the app shell.
//
// Usage: KUBUS_BASE=http://localhost:8081 node scripts/qa/web_routing_contract.mjs

import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const BASE = (process.env.KUBUS_BASE ?? 'http://localhost:8081').replace(/\/+$/, '');
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const routeManifest = JSON.parse(await readFile(
  resolve(repoRoot, 'web', 'web_interactive_routes.json'),
  'utf8',
));
// index.html (the Flutter shell) opens with the HTML doctype; seo-proxy.php opens
// with `<?php`. These two markers, not the presence of "flutter_bootstrap.js"
// (which the gateway's own source references), are what reliably distinguish the
// two rewrite targets when Apache serves the raw .php file with no PHP module.
const APP_SHELL_DOCTYPE = /^\s*<!doctype html/i;
const GATEWAY_SOURCE = /^\s*<\?php/;

const results = [];
function record(name, ok, detail) {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}\n      ${detail}`);
}

async function fetchManual(path) {
  const res = await fetch(`${BASE}${path}`, { redirect: 'manual' });
  return { status: res.status, text: await res.text() };
}

async function expectAppShell(path) {
  const { status, text } = await fetchManual(path);
  const ok = status === 200 && APP_SHELL_DOCTYPE.test(text);
  record(`${path} boots the app shell`, ok, `${status} doctype=${APP_SHELL_DOCTYPE.test(text)} (expected 200 + index.html doctype)`);
}

async function expectGatewayHandoff(path) {
  const { status, text } = await fetchManual(path);
  // The deeper localized route must route to seo-proxy.php, NOT index.html. With
  // no PHP module the gateway source is served verbatim, so its `<?php` opener
  // (and the absence of the shell doctype) proves the rewrite target.
  const ok = status === 200 && GATEWAY_SOURCE.test(text) && !APP_SHELL_DOCTYPE.test(text);
  record(`${path} hands off to the SEO renderer`, ok, `${status} gateway=${GATEWAY_SOURCE.test(text)} shell=${APP_SHELL_DOCTYPE.test(text)} (expected 200 + gateway source)`);
}

async function expectStatus(path, expected) {
  const { status } = await fetchManual(path);
  record(`${path}`, status === expected, `${status} (expected ${expected})`);
}

async function expectRedirect(path, expectedStatus, expectedLocation) {
  const res = await fetch(`${BASE}${path}`, { redirect: 'manual' });
  const rawLocation = res.headers.get('location');
  const location = rawLocation === null ? null : new URL(rawLocation, `${BASE}/`).pathname;
  const ok = res.status === expectedStatus && location === expectedLocation;
  record(`${path} redirects canonically`, ok, `${res.status} ${location ?? '<no location>'} (expected ${expectedStatus} ${expectedLocation})`);
}

console.log(`web/.htaccess routing contract against ${BASE}\n`);

// --- Complete canonical interactive route surface ---------------------------
// The same manifest generates Apache's finite allowlist. Iterating it here
// proves the complete contract through real mod_rewrite rather than merely
// comparing regex strings.
for (const route of routeManifest.routes) {
  await expectAppShell(route.testUrl);
}

// Locale/tracking query parameters enter the app rather than redirecting: the
// launch locale is resolved inside the app and the query survives untouched.
await expectAppShell('/?lang=sl');
await expectAppShell('/?lang=en');
await expectAppShell('/?locale=en');
await expectAppShell('/?utm_source=test');
await expectAppShell('/?lang=sl&utm_source=test');

// --- Deeper localized public routes stay server-rendered --------------------
// These are owned by the SEO renderer (seo-proxy.php); they must not degrade
// into the app shell. The renderer decides eligibility and real 404s at runtime.
await expectGatewayHandoff('/en/artworks/contract-probe');
await expectGatewayHandoff('/sl/umetnine/contract-probe');

// Compact and long-form entity aliases remain renderer-owned. The PHP-less CI
// container proves the handoff target; production contract tests prove the
// renderer's canonical redirect and semantic response.
await expectGatewayHandoff('/a/contract-probe');
await expectGatewayHandoff('/artworks/contract-probe');

// The oldest marker query alias remains a one-hop locale-aware redirect.
await expectRedirect('/map?marker=contract-probe', 308, '/en/map/contract-probe');

// --- Honest failure behaviour -----------------------------------------------
// Unknown paths are real 404s, never an indexable Flutter shell.
await expectStatus('/__unknown-routing-probe', 404);
await expectStatus('/does/not/exist', 404);
await expectGatewayHandoff('/en/__unknown-routing-probe');
await expectGatewayHandoff('/sl/__unknown-routing-probe');
await expectStatus('/missing-runtime.js.map', 404);

const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} checks passed.`);
if (failed.length > 0) {
  console.log('\nFailed checks:');
  for (const f of failed) console.log(`  - ${f.name}: ${f.detail}`);
  process.exit(1);
}
