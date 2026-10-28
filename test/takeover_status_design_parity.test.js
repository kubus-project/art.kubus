'use strict';

// The WORLD HANDOFF design lives in the backend (src/services/takeoverStatusDesign.js) and is copied,
// byte for byte, into web/seo-proxy.php by scripts/sync_takeover_status_design.mjs. The backend test pins the
// same SHA-256, so a change to one side without the other fails CI on whichever repository is behind.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const SEO_PROXY = path.join(__dirname, '..', 'web', 'seo-proxy.php');
const DESIGN_SHA256 = 'f8be2c08e74a07cadee1bfcf2cebb0b663961bf947f75963ff6e7267450268f4';

// A PHP constant defined as concatenated single-quoted literals (no escapes: the sync script refuses quotes and backslashes).
const phpConstant = (source, name) => {
  const match = new RegExp(`const ${name} = ([\\s\\S]*?);\\r?\\n`).exec(source);
  assert.ok(match, `${name} exists in seo-proxy.php`);
  return [...match[1].matchAll(/'([^']*)'/g)].map((m) => m[1]).join('');
};

test('the PHP gateway carries the pinned WORLD HANDOFF design, byte for byte', () => {
  const php = fs.readFileSync(SEO_PROXY, 'utf8');
  const css = phpConstant(php, 'KUBUS_TAKEOVER_STATUS_CSS');
  const svg = phpConstant(php, 'KUBUS_TAKEOVER_GLOBE_SVG');
  const hash = crypto.createHash('sha256').update(`${css}\u0000${svg}`).digest('hex');
  assert.equal(hash, DESIGN_SHA256, 'run scripts/sync_takeover_status_design.mjs <backend> and update both pinned hashes');
});

test('the PHP gateway section carries the same structure and copy as the backend section', () => {
  const php = fs.readFileSync(SEO_PROXY, 'utf8');
  for (const copy of [
    'THE WORLD IS OPENING',
    'Preparing the full interactive experience. You can keep exploring this page while it loads.',
    'SVET UMETNOSTI SE ODPIRA',
    'Pripravljamo celotno interaktivno izkušnjo. Med nalaganjem lahko še naprej raziskujete to stran.',
  ]) {
    assert.ok(php.includes(copy), `gateway has ${copy}`);
  }
  assert.match(php, /\. KUBUS_TAKEOVER_GLOBE_SVG/);
  assert.match(php, /class="takeover-label"/);
  assert.match(php, /class="takeover-note"/);
  assert.match(php, /class="takeover-trace" aria-hidden="true"/);
  // the same child order as the backend: globe, head (label, message), note, trace, actions
  const order = ['KUBUS_TAKEOVER_GLOBE_SVG', 'class="takeover-head"', 'class="takeover-label"', 'data-kubus-takeover-message', 'class="takeover-note"', 'class="takeover-trace"', 'data-kubus-takeover-actions'].map((needle) => {
    const index = php.indexOf(needle, php.indexOf('function takeoverStatusMarkup'));
    assert.ok(index > 0, `${needle} in the gateway markup`);
    return index;
  });
  assert.deepEqual(order, [...order].sort((x, y) => x - y), 'child order matches the backend');
  // one live region, on the message only
  const markup = /function takeoverStatusMarkup[\s\S]*?\n}\n/.exec(php)[0];
  assert.equal(markup.match(/role="status"/g).length, 1);
  // label and message sit inside the head wrapper, and the wrapper closes before the note
  assert.match(
    markup,
    /'<span class="takeover-head">'[\s\S]*?class="takeover-label"[\s\S]*?data-kubus-takeover-message[\s\S]*?'<\/span>'\s*\.\s*'<span class="takeover-note">'/,
    'label and message are inside takeover-head, which closes before the note',
  );
});
