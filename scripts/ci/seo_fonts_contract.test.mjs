// The server-rendered public pages (backend) load their brand fonts from /seo-fonts/ on the same origin, so no
// visitor address reaches a font provider. The files are shipped by the web build from web/seo-fonts.
import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';
import test from 'node:test';

const dir = new URL('../../web/seo-fonts/', import.meta.url);
const files = [
  'sofia-sans-latin.woff2', 'sofia-sans-latin-ext.woff2',
  'space-mono-400-latin.woff2', 'space-mono-400-latin-ext.woff2',
  'space-mono-700-latin.woff2', 'space-mono-700-latin-ext.woff2',
];

test('the public pages brand fonts are shipped as woff2 with their licence', () => {
  for (const name of files) {
    const bytes = readFileSync(new URL(name, dir));
    assert.equal(bytes.subarray(0, 4).toString('latin1'), 'wOF2', `${name} is not a WOFF2 file`);
    assert.ok(statSync(new URL(name, dir)).size < 60 * 1024, `${name} is unexpectedly large`);
  }
  assert.match(readFileSync(new URL('OFL.txt', dir), 'utf8'), /SIL OPEN FONT LICENSE/i);
});
