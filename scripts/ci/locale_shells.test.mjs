import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import test from 'node:test';

import { localeShell, localeShells } from '../deploy/locale_shells.mjs';

const root = readFileSync(resolve(import.meta.dirname, '../../web/index.html'), 'utf8');
const get = (html, re) => html.match(re)?.[1];
const alternates = (html) => Object.fromEntries([...html.matchAll(/<link rel="alternate" hreflang="([^"]+)" href="([^"]+)">/g)].map((m) => [m[1], m[2]]));
const jsonLd = (html) => JSON.parse(get(html, /<script type="application\/ld\+json">([\s\S]*?)<\/script>/));

test('root is its own canonical, x-default alternate, and carries the WebSite identity art.kubus', () => {
  assert.equal(get(root, /<link rel="canonical" href="([^"]+)">/), 'https://app.kubus.site/');
  assert.equal(get(root, /<meta property="og:url" content="([^"]+)">/), 'https://app.kubus.site/');
  assert.deepEqual(alternates(root), { en: 'https://app.kubus.site/en', sl: 'https://app.kubus.site/sl', 'x-default': 'https://app.kubus.site/' });
  const site = jsonLd(root)['@graph'].find((n) => n['@type'] === 'WebSite');
  assert.equal(site.name, 'art.kubus');
  assert.equal(site.url, 'https://app.kubus.site/');
  assert.equal(get(root, /<meta property="og:site_name" content="([^"]+)">/), 'art.kubus');
});

test('each bare locale root is self-canonical with reciprocal hreflang and its own language', () => {
  const shells = localeShells(root);
  for (const [file, locale] of [['index.en.html', 'en'], ['index.sl.html', 'sl']]) {
    const html = shells[file];
    assert.equal(get(html, /<link rel="canonical" href="([^"]+)">/), `https://app.kubus.site/${locale}`);
    assert.equal(get(html, /<meta property="og:url" content="([^"]+)">/), `https://app.kubus.site/${locale}`);
    assert.deepEqual(alternates(html), alternates(root), 'reciprocal alternates are identical on every shell');
    assert.match(html, new RegExp(`<html lang="${locale}">`));
    assert.equal(get(html, /<meta property="og:site_name" content="([^"]+)">/), 'art.kubus');
  }
});

test('the Slovenian shell has Slovenian title, description and Open Graph; the English one is unchanged text', () => {
  const sl = localeShell(root, 'sl');
  const en = localeShell(root, 'en');
  assert.match(get(sl, /<title>([^<]*)<\/title>/), /^art\.kubus — Odprti zemljevid/);
  assert.match(get(sl, /<meta name="description" content="([^"]+)">/), /^Odkrivajte javno umetnost/);
  assert.equal(get(sl, /<meta property="og:locale" content="([^"]+)">/), 'sl_SI');
  assert.equal(get(sl, /<meta name="twitter:title" content="([^"]+)">/), get(sl, /<title>([^<]*)<\/title>/));
  assert.equal(get(en, /<title>([^<]*)<\/title>/), get(root, /<title>([^<]*)<\/title>/));
  assert.notEqual(get(sl, /<title>([^<]*)<\/title>/), get(en, /<title>([^<]*)<\/title>/));
});

test('icons, approved social image and manifest are declared on the root and inherited by the shells', () => {
  for (const html of [root, localeShell(root, 'sl')]) {
    assert.match(html, /<link rel="icon" href="\/favicon\.ico" sizes="any">/);
    assert.match(html, /<link rel="apple-touch-icon" href="\/apple-touch-icon\.png">/);
    assert.equal(get(html, /<meta property="og:image" content="([^"]+)">/), 'https://app.kubus.site/images/social-preview.png');
    assert.equal(get(html, /<meta property="og:image:type" content="([^"]+)">/), 'image/png');
  }
});

test('a shell derivation fails loudly when the root document changes shape', () => {
  assert.throws(() => localeShell(root.replace(/<link rel="canonical"[^>]*>/, ''), 'en'), /canonical/);
  assert.throws(() => localeShell(root.replace('<html lang="en">', '<html>'), 'sl'), /html lang/);
});

test('the Apache rules serve derived shells when present and fall back to the root document otherwise', () => {
  const htaccess = readFileSync(resolve(import.meta.dirname, '../../web/.htaccess'), 'utf8');
  assert.match(htaccess, /RewriteCond %\{DOCUMENT_ROOT\}\/index\.sl\.html -f\s+RewriteRule \^sl\/\?\$ index\.sl\.html \[L\]/);
  assert.match(htaccess, /RewriteRule \^\(\?:en\|sl\)\/\?\$ index\.html \[L\]/);
});
