const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function harness(locale = 'en') {
  const listeners = new Map();
  const classes = new Set();
  const timers = new Map();
  let currentTime = 0;
  let nextTimerId = 0;
  let reloadCount = 0;
  const classList = {
    add: (...names) => names.forEach((name) => classes.add(name)),
    remove: (...names) => names.forEach((name) => classes.delete(name)),
    contains: (name) => classes.has(name),
  };
  const attrs = new Map();
  const message = { textContent: '' };
  const refreshButton = {
    hidden: true,
    textContent: '',
    addEventListener(name, callback) { this[name] = callback; },
  };
  const status = {
    dataset: {
      state: 'pending',
      locale,
      loadingText: locale === 'sl'
        ? 'Svet umetnosti se izrisuje …'
        : 'The world of art is coming into focus…',
      failureText: locale === 'sl'
        ? 'Svet umetnosti se tokrat ni mogel odpreti. Poskusite osvežiti stran ali se vrnite pozneje.'
        : "The world of art couldn't open this time. Try refreshing the page or come back later.",
      refreshLabel: locale === 'sl' ? 'Osveži' : 'Refresh',
    },
    hidden: false,
    querySelector(selector) {
      if (selector === '[data-kubus-takeover-message]') return message;
      if (selector === '[data-kubus-takeover-refresh]') return refreshButton;
      return null;
    },
    insertBefore(node) { this.insertedMessage = node; },
  };
  const host = {
    dataset: {
      entityType: 'artwork',
      entityId: 'art-1',
      entityPath: `/${locale}/${locale === 'sl' ? 'umetnine' : 'artworks'}/art-1`,
      locale,
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
  class HTMLScriptElement {
    constructor(src) { this.src = src; }
  }
  const global = {
    document: {
      documentElement: { classList },
      getElementById: (id) => id === 'flutter-host' ? host : id === 'public-document' ? publicDocument : null,
      querySelector: (selector) => selector === '[data-kubus-takeover-status]' ? status : null,
      createElement: () => ({ dataset: {}, textContent: '' }),
    },
    location: {
      pathname: host.dataset.entityPath,
      href: `https://app.kubus.site${host.dataset.entityPath}`,
      reload: () => { reloadCount += 1; },
    },
    performance: { mark() {} },
    matchMedia: () => ({ matches: true }),
    setTimeout: (callback, delay) => {
      const id = ++nextTimerId;
      timers.set(id, { callback, at: currentTime + delay });
      return id;
    },
    clearTimeout: (id) => timers.delete(id),
    addEventListener: (name, callback) => listeners.set(name, [...(listeners.get(name) || []), callback]),
    removeEventListener(name, callback) {
      const remaining = (listeners.get(name) || []).filter((item) => item !== callback);
      if (remaining.length) listeners.set(name, remaining);
      else listeners.delete(name);
    },
    dispatchEvent(event) { (listeners.get(event.type) || []).forEach((cb) => cb(event)); },
    CustomEvent,
    HTMLScriptElement,
    URL,
  };
  global.globalThis = global;
  const filename = path.join(__dirname, '..', 'web', 'public_flutter_takeover.js');
  vm.runInNewContext(fs.readFileSync(filename, 'utf8'), global, { filename });

  const advance = (duration) => {
    const until = currentTime + duration;
    while (true) {
      const next = [...timers.entries()]
        .filter(([, timer]) => timer.at <= until)
        .sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      const [id, timer] = next;
      timers.delete(id);
      currentTime = timer.at;
      timer.callback();
    }
    currentTime = until;
  };

  const dispatchEntity = (detail) => global.dispatchEvent(
    new global.CustomEvent('kubus:public-entity-ready', { detail }),
  );

  return {
    global,
    classes,
    attrs,
    status,
    message,
    refreshButton,
    advance,
    dispatchEntity,
    get reloadCount() { return reloadCount; },
  };
}

test('engine and route readiness alone never replace the semantic document', () => {
  const page = harness();
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.global.kubusPublicTakeover.engineReady();
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-route-parsed', {
    detail: { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'en' },
  }));
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.attrs.get('document:aria-hidden'), undefined);
  page.advance(499);
  assert.equal(page.status.hidden, true);
  page.advance(1);
  assert.equal(page.status.dataset.state, 'loading');
  assert.equal(page.message.textContent, 'The world of art is coming into focus…');
});

test('only the exact entity, localized path, locale and current pathname can take over', () => {
  const page = harness();
  for (const detail of [
    { type: 'artwork', id: 'other', path: '/en/artworks/art-1', locale: 'en' },
    { type: 'artwork', id: 'art-1', path: '/en/artworks/other', locale: 'en' },
    { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'sl' },
  ]) page.dispatchEntity(detail);

  page.global.location.pathname = '/sl/umetnine/art-1';
  page.dispatchEntity({ type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'en' });
  assert.equal(page.classes.has('kubus-takeover-active'), false);

  page.global.location.pathname = '/en/artworks/art-1';
  page.dispatchEntity({ type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'en' });
  assert.equal(page.classes.has('kubus-takeover-active'), true);
  assert.equal(page.classes.has('kubus-takeover-complete'), true);
  assert.equal(page.attrs.get('document:aria-hidden'), 'true');
  assert.equal(page.status.hidden, true);
});

test('the eight-second slow state keeps loading copy and does not fail', () => {
  const page = harness('sl');
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.advance(500);
  assert.equal(page.status.dataset.state, 'loading');
  page.advance(7500);
  assert.equal(page.status.dataset.state, 'slow');
  assert.equal(page.message.textContent, 'Svet umetnosti se izrisuje …');
  assert.equal(page.refreshButton.hidden, true);
  assert.equal(page.classes.has('kubus-takeover-active'), false);
});

test('actual failure keeps SSR visible and offers one manual refresh', () => {
  const page = harness('sl');
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.advance(500);
  page.global.kubusPublicTakeover.fail();
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.attrs.get('document:aria-hidden'), undefined);
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.message.textContent,
    'Svet umetnosti se tokrat ni mogel odpreti. Poskusite osvežiti stran ali se vrnite pozneje.');
  assert.equal(page.refreshButton.hidden, false);
  assert.equal(page.refreshButton.textContent, 'Osveži');
  assert.equal(page.reloadCount, 0, 'failure never retries automatically');
  page.refreshButton.click();
  assert.equal(page.reloadCount, 1);
  page.dispatchEntity({ type: 'artwork', id: 'art-1', path: '/sl/umetnine/art-1', locale: 'sl' });
  assert.equal(page.classes.has('kubus-takeover-active'), false,
    'a late ready signal cannot cover a failed SSR page');
});

test('a resource error after engine readiness enters the manual failure state', () => {
  const page = harness();
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.global.kubusPublicTakeover.engineReady();
  // Dispatch through the browser event listener registered by the script.
  page.global.dispatchEvent({
    type: 'error',
    target: new page.global.HTMLScriptElement('https://app.kubus.site/canvaskit/chromium/canvaskit.js'),
  });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.refreshButton.hidden, false);
});

test('a Flutter bootstrap script error enters failure before engine readiness', () => {
  const page = harness();
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.global.dispatchEvent({
    type: 'error',
    target: new page.global.HTMLScriptElement('https://app.kubus.site/flutter_bootstrap.js'),
  });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.refreshButton.hidden, false);
  assert.equal(page.reloadCount, 0);
});
