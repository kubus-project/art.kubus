// Regenerates the WORLD HANDOFF design constants in web/seo-proxy.php from the backend's
// src/services/takeoverStatusDesign.js (the source of truth), so the two cannot drift.
//
//   node scripts/sync_takeover_status_design.mjs <path to art.kubus-backend>
//
// test/takeover_status_design_parity.test.js pins the same SHA-256 the backend test pins.
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const backend = resolve(process.argv[2] ?? '');
if (!process.argv[2]) {
  console.error('usage: node scripts/sync_takeover_status_design.mjs <path to art.kubus-backend>');
  process.exit(2);
}
const design = createRequire(import.meta.url)(resolve(backend, 'src/services/takeoverStatusDesign.js'));
for (const text of [...design.TAKEOVER_STATUS_CSS_RULES, design.GLOBE_SVG]) {
  if (text.includes("'") || text.includes(String.fromCharCode(92))) throw new Error('design text must not contain a quote or backslash (PHP single-quoted literal)');
}

const file = resolve(root, 'web/seo-proxy.php');
const php = readFileSync(file, 'utf8');
const nl = php.includes('\r\n') ? '\r\n' : '\n';
const start = php.indexOf('// The WORLD HANDOFF section design.');
const fallback = php.indexOf("// Tokens are the site's custom properties");
const from = start >= 0 ? start : fallback;
const to = php.indexOf('function sendGatewayError');
if (from < 0 || to < 0) throw new Error('markers not found in seo-proxy.php');
const block = [
  "// The WORLD HANDOFF section design. A byte-identical copy of the backend's takeoverStatusDesign.js (both repositories pin the same hash in a test);",
  "// section-local tokens fall back to the document's own tokens, so it stays legible on a page without them.",
  `const KUBUS_TAKEOVER_STATUS_CSS = '${design.TAKEOVER_STATUS_CSS_RULES.join(`'${nl}    . '`)}';`,
  '',
  `const KUBUS_TAKEOVER_GLOBE_SVG = '${design.GLOBE_SVG}';`,
  '',
  '',
].join(nl);
writeFileSync(file, php.slice(0, from) + block + php.slice(to));
console.log('seo-proxy.php design constants synced');
