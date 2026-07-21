#!/usr/bin/env node
// Apache rewrite contract for web/.htaccess.
//
// Runs against a real Apache serving web/ with AllowOverride All. mod_rewrite
// behaviour cannot be inferred by reading the file: rule order, [L] termination
// and QSA/QSD query handling all interact. The lang= stripping in particular
// needs four separate rules because QSA cannot express "drop one parameter,
// keep the rest", and only execution proves the joining is right.
//
// PHP is not required: every assertion here concerns redirects and static
// routing decided before the seo-proxy.php handoff.
//
// Usage: KUBUS_BASE=http://localhost:8081 node scripts/qa/web_routing_contract.mjs

const BASE = (process.env.KUBUS_BASE ?? 'http://localhost:8081').replace(/\/+$/, '');

const results = [];
function record(name, ok, detail) {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}\n      ${detail}`);
}

async function redirectOf(path) {
  const res = await fetch(`${BASE}${path}`, { redirect: 'manual' });
  const raw = res.headers.get('location');
  return {
    status: res.status,
    target: raw === null ? null : new URL(raw, `${BASE}/`).pathname + new URL(raw, `${BASE}/`).search,
  };
}

async function expectRedirect(path, expectedStatus, expectedTarget) {
  const { status, target } = await redirectOf(path);
  const ok = status === expectedStatus && target === expectedTarget;
  record(`${path}`, ok, `${status} ${target ?? '<none>'} (expected ${expectedStatus} ${expectedTarget})`);
}

async function expectStatus(path, expected) {
  const res = await fetch(`${BASE}${path}`, { redirect: 'manual' });
  record(`${path}`, res.status === expected, `${res.status} (expected ${expected})`);
}

console.log(`web/.htaccess routing contract against ${BASE}\n`);

// --- Root canonicalization ---------------------------------------------------
await expectRedirect('/', 308, '/en');

// ?lang= selects the locale and is dropped; tracking parameters survive.
await expectRedirect('/?lang=sl', 308, '/sl');
await expectRedirect('/?lang=en', 308, '/en');
await expectRedirect('/?utm_source=test', 308, '/en?utm_source=test');
await expectRedirect('/?lang=sl&utm_source=test', 308, '/sl?utm_source=test');
await expectRedirect('/?utm_source=test&lang=sl', 308, '/sl?utm_source=test');
await expectRedirect('/?utm_source=test&lang=sl&utm_medium=cpc', 308, '/sl?utm_source=test&utm_medium=cpc');

// Matching is case-sensitive because the captured locale becomes the redirect
// target: accepting ?lang=SL would emit /SL. Unrecognized values fall through
// to the default English canonical with the query untouched.
await expectRedirect('/?lang=SL', 308, '/en?lang=SL');
await expectRedirect('/?lang=slovenia', 308, '/en?lang=slovenia');

// --- App namespace and finite route surface ---------------------------------
await expectStatus('/app', 200);
await expectStatus('/main', 200);
await expectStatus('/map', 200);

// Unknown paths are real 404s, never an indexable Flutter shell.
await expectStatus('/__unknown-routing-probe', 404);
await expectStatus('/does/not/exist', 404);

const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} checks passed.`);
if (failed.length > 0) {
  console.log('\nFailed checks:');
  for (const f of failed) console.log(`  - ${f.name}: ${f.detail}`);
  process.exit(1);
}
