'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const ROOT = path.join(__dirname, '..');
const CAPABILITY = fs.readFileSync(
  path.join(ROOT, 'web', 'takeover_capability.js'),
  'utf8',
);

function runCapability({ language, languages, htmlLanguage = '' }) {
  const navigator = {};
  Object.defineProperty(navigator, 'language', {
    configurable: true,
    value: language,
    writable: true,
  });
  Object.defineProperty(navigator, 'languages', {
    configurable: true,
    value: languages,
    writable: true,
  });

  const classes = [];
  const document = {
    documentElement: {
      lang: htmlLanguage,
      classList: { add: (value) => classes.push(value) },
    },
    addEventListener() {},
    getElementById() { return null; },
  };
  vm.runInNewContext(CAPABILITY, {
    document,
    window: { navigator },
    Intl,
    setTimeout() {},
  });

  return {
    language: navigator.language,
    languages: navigator.languages,
    htmlLanguage: document.documentElement.lang,
    classes,
  };
}

test('undefined and malformed browser languages fall back before Flutter startup', () => {
  const result = runCapability({
    language: undefined,
    languages: [undefined, 'undefined', null, 'null', 'en_US', '***', ''],
    htmlLanguage: 'undefined',
  });

  assert.equal(result.language, 'en-US');
  assert.deepEqual([...result.languages], ['en-US', 'en']);
  assert.equal(result.htmlLanguage, 'en');
  assert.deepEqual(result.classes, ['kubus-takeover-capable']);
});

test('valid locale values and their order are preserved while invalid entries are removed', () => {
  const result = runCapability({
    language: 'sl-SI',
    languages: ['undefined', 'sl-SI', 'en-GB', 'en_US'],
    htmlLanguage: 'sl',
  });

  assert.equal(result.language, 'sl-SI');
  assert.deepEqual([...result.languages], ['sl-SI', 'en-GB']);
  assert.equal(result.htmlLanguage, 'sl');
});

test('ordinary and SSR shells load the same blocking capability before Flutter', () => {
  const index = fs.readFileSync(path.join(ROOT, 'web', 'index.html'), 'utf8');
  const standardCapability = index.indexOf(
    '<script src="/takeover_capability.js"></script>',
  );
  const standardBootstrap = index.indexOf('src="flutter_bootstrap.js"');
  assert.ok(standardCapability >= 0, 'the standard shell loads the shared guard');
  assert.ok(standardCapability < standardBootstrap);
  assert.doesNotMatch(index, /Guard Flutter web locale bootstrap/);

  const gateway = fs.readFileSync(path.join(ROOT, 'web', 'seo-proxy.php'), 'utf8');
  assert.match(gateway, /'<script src="\/takeover_capability\.js"><\/script>'/);
  assert.match(
    gateway,
    /preg_replace\('\/<\\\/head>\/i', \$takeoverStyle \. \$capabilityScript \. '<\/head>'/,
  );
});
