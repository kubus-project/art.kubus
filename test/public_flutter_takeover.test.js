const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function harness() {
  const listeners = new Map();
  const classes = new Set();
  let timerCount = 0;
  const classList = {
    add: (...names) => names.forEach((name) => classes.add(name)),
    remove: (...names) => names.forEach((name) => classes.delete(name)),
    contains: (name) => classes.has(name),
  };
  const attrs = new Map();
  const host = {
    dataset: {
      entityType: 'artwork',
      entityId: 'art-1',
      entityPath: '/en/artworks/art-1',
    },
    setAttribute: (name, value) => attrs.set(name, value),
    removeAttribute: (name) => attrs.delete(name),
    addEventListener() {},
    removeEventListener() {},
  };
  const publicDocument = {
    setAttribute: (name, value) => attrs.set(`document:${name}`, value),
    removeAttribute: (name) => attrs.delete(`document:${name}`),
  };
  class CustomEvent {
    constructor(type, init = {}) { this.type = type; this.detail = init.detail; }
  }
  const global = {
    document: {
      documentElement: { classList },
      getElementById: (id) => id === 'flutter-host' ? host : id === 'public-document' ? publicDocument : null,
    },
    location: { pathname: '/en/artworks/art-1', href: 'https://app.kubus.site/en/artworks/art-1' },
    performance: { mark() {} },
    matchMedia: () => ({ matches: true }),
    setTimeout: () => { timerCount += 1; return timerCount; },
    clearTimeout() {},
    addEventListener: (name, cb) => listeners.set(name, [...(listeners.get(name) || []), cb]),
    removeEventListener(name) { listeners.delete(name); },
    dispatchEvent(event) { (listeners.get(event.type) || []).forEach((cb) => cb(event)); },
    CustomEvent,
    HTMLScriptElement: class HTMLScriptElement {},
  };
  global.globalThis = global;
  const filename = path.join(__dirname, '..', 'web', 'public_flutter_takeover.js');
  vm.runInNewContext(fs.readFileSync(filename, 'utf8'), global, { filename });
  return { global, classes, attrs, get timerCount() { return timerCount; } };
}

test('engine and route readiness alone never replace the semantic document', () => {
  const page = harness();
  page.global.kubusPublicTakeover.engineReady();
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-route-parsed', {
    detail: { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1' },
  }));
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.attrs.get('document:aria-hidden'), undefined);
  assert.equal(page.timerCount, 0);
});

test('only the exact entity and current pathname can claim the painted takeover', () => {
  const page = harness();
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-ready', {
    detail: { type: 'artwork', id: 'other', path: '/en/artworks/art-1' },
  }));
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-ready', {
    detail: { type: 'artwork', id: 'art-1', path: '/en/artworks/other' },
  }));
  page.global.location.pathname = '/en/artworks/other';
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-ready', {
    detail: { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1' },
  }));
  assert.equal(page.classes.has('kubus-takeover-active'), false);

  page.global.location.pathname = '/en/artworks/art-1';
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-ready', {
    detail: { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1' },
  }));
  assert.equal(page.classes.has('kubus-takeover-active'), true);
  assert.equal(page.classes.has('kubus-takeover-complete'), true);
  assert.equal(page.attrs.get('document:aria-hidden'), 'true');
});

test('failure before or after readiness leaves the SSR document active', () => {
  const page = harness();
  page.global.kubusPublicTakeover.fail();
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.attrs.get('document:aria-hidden'), undefined);
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-ready', {
    detail: { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1' },
  }));
  page.global.kubusPublicTakeover.fail();
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.attrs.get('document:aria-hidden'), undefined);
});
