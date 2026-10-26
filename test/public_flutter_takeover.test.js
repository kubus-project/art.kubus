const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

function harness(locale = 'en', options = {}) {
  const listeners = new Map();
  const classes = new Set();
  const timers = new Map();
  const marks = [];
  const documentListeners = new Map();
  let currentTime = 0;
  let nextTimerId = 0;
  let reloadCount = 0;
  // Resource Timing entries for the document (options.resourceEntries), read at takeover execution.
  const resourceEntries = options.resourceEntries || [];
  // The Flutter bootstrap script element, when the page already contains it (options.bootstrapElement).
  let bootstrapScript = null;
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
  if (options.bootstrapElement) {
    const element = new HTMLScriptElement('https://app.kubus.site/flutter_bootstrap.js');
    const elementListeners = new Map();
    element.addEventListener = (name, callback) => elementListeners.set(name, [...(elementListeners.get(name) || []), callback]);
    element.removeEventListener = (name, callback) => elementListeners.set(name, (elementListeners.get(name) || []).filter((item) => item !== callback));
    element.dispatch = (name, event) => (elementListeners.get(name) || []).forEach((cb) => cb({ ...event, target: element }));
    element.listenerCount = (name) => (elementListeners.get(name) || []).length;
    bootstrapScript = element;
  }
  const global = {
    document: {
      documentElement: { classList },
      readyState: options.readyState || 'interactive',
      getElementById: (id) => id === 'flutter-host' ? host : id === 'public-document' ? publicDocument : null,
      querySelector: (selector) => {
        if (selector === '[data-kubus-takeover-status]') return status;
        if (selector === 'script[src*="flutter_bootstrap.js"]') return bootstrapScript;
        return null;
      },
      createElement: () => ({ dataset: {}, textContent: '' }),
      addEventListener: (name, callback) => documentListeners.set(name, [...(documentListeners.get(name) || []), callback]),
    },
    location: {
      pathname: host.dataset.entityPath,
      href: `https://app.kubus.site${host.dataset.entityPath}`,
      reload: () => { reloadCount += 1; },
    },
    performance: {
      mark: (name) => marks.push(name),
      getEntriesByType: (type) => (type === 'resource' ? resourceEntries : []),
    },
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
    marks,
    bootstrapScript,
    fireDocumentEvent: (name) => (documentListeners.get(name) || []).forEach((cb) => cb({ type: name })),
    get reloadCount() { return reloadCount; },
  };
}

const bootstrapEntry = (responseStatus) => ({
  name: 'https://app.kubus.site/flutter_bootstrap.js',
  responseStatus,
});

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

test('a bootstrap element error alone, with no window capture event, enters failure', () => {
  const page = harness('en', { bootstrapElement: true });
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.bootstrapScript.dispatch('error', { type: 'error' });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.message.textContent, "The world of art couldn't open this time. Try refreshing the page or come back later.");
  assert.equal(page.refreshButton.hidden, false);
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.reloadCount, 0, 'failure never retries automatically');
});

test('window capture and bootstrap element signals for one request make a single failure transition', () => {
  for (const order of [['window', 'element'], ['element', 'window']]) {
    const page = harness('en', { bootstrapElement: true });
    page.global.kubusPublicTakeover.bootstrapStarted();
    const fireWindow = () => page.global.dispatchEvent({
      type: 'error',
      target: new page.global.HTMLScriptElement('https://app.kubus.site/flutter_bootstrap.js'),
    });
    const fireElement = () => page.bootstrapScript.dispatch('error', { type: 'error' });
    for (const signal of order) (signal === 'window' ? fireWindow : fireElement)();
    fireWindow();
    fireElement();
    assert.equal(page.status.dataset.state, 'failed', order.join(' then '));
    assert.equal(page.marks.filter((name) => name === 'flutter_takeover_failed').length, 1,
      `one failure mark for ${order.join(' then ')}`);
    assert.equal(page.refreshButton.hidden, false);
    assert.equal(page.reloadCount, 0);
  }
});

test('a bootstrap request that failed before the takeover script ran enters failure (Firefox deferred ordering)', () => {
  const page = harness('en', { resourceEntries: [bootstrapEntry(0)] });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.status.hidden, false);
  assert.equal(page.refreshButton.hidden, false);
  assert.equal(page.refreshButton.textContent, 'Refresh');
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.reloadCount, 0);
});

test('an HTTP error response for the bootstrap request enters failure', () => {
  const page = harness('sl', { resourceEntries: [bootstrapEntry(404)] });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.refreshButton.textContent, 'Osveži');
});

test('a successful status-200 bootstrap entry never fails, before or after DOMContentLoaded', () => {
  const page = harness('en', { resourceEntries: [bootstrapEntry(200)] });
  assert.equal(page.status.dataset.state, 'pending');
  assert.equal(page.refreshButton.hidden, true);
  page.fireDocumentEvent('DOMContentLoaded');
  assert.equal(page.status.dataset.state, 'pending');
  assert.equal(page.refreshButton.hidden, true);
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
  assert.equal(page.reloadCount, 0);
});

test('an undefined responseStatus (older browsers) never fails the takeover', () => {
  const page = harness('en', { resourceEntries: [bootstrapEntry(undefined)] });
  assert.equal(page.status.dataset.state, 'pending');
  page.fireDocumentEvent('DOMContentLoaded');
  assert.equal(page.status.dataset.state, 'pending');
  assert.equal(page.refreshButton.hidden, true);
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.advance(500);
  assert.equal(page.status.dataset.state, 'loading');
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
  assert.equal(page.reloadCount, 0);
});

test('a pending or successful bootstrap request never fails the takeover', () => {
  const pending = harness('en', { resourceEntries: [] });
  pending.fireDocumentEvent('DOMContentLoaded');
  assert.equal(pending.status.dataset.state, 'pending');

  const loaded = harness('en', { resourceEntries: [bootstrapEntry(200)] });
  loaded.fireDocumentEvent('DOMContentLoaded');
  loaded.global.kubusPublicTakeover.bootstrapStarted();
  loaded.advance(500);
  assert.equal(loaded.status.dataset.state, 'loading');
  assert.equal(loaded.marks.includes('flutter_takeover_failed'), false);
});

test('a request that fails after the takeover script ran is caught by the DOMContentLoaded recheck', () => {
  const entries = [];
  const page = harness('en', { resourceEntries: entries });
  assert.equal(page.status.dataset.state, 'pending');
  entries.push(bootstrapEntry(0));
  page.fireDocumentEvent('DOMContentLoaded');
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.marks.filter((name) => name === 'flutter_takeover_failed').length, 1);
});

test('a Flutter failed-entity signal reuses the one idempotent failure transition', () => {
  const page = harness('en', { bootstrapElement: true });
  const exact = { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'en' };
  const signalFailed = (detail) => page.global.dispatchEvent(
    new page.global.CustomEvent('kubus:public-entity-failed', { detail }),
  );
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.advance(8000);
  assert.equal(page.status.dataset.state, 'slow');

  signalFailed({ ...exact, id: 'other' });
  assert.equal(page.status.dataset.state, 'slow', 'another entity cannot fail this takeover');

  signalFailed(JSON.stringify(exact));
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.message.textContent, "The world of art couldn't open this time. Try refreshing the page or come back later.");
  assert.equal(page.refreshButton.hidden, false);
  assert.equal(page.classes.has('kubus-takeover-active'), false);

  // Repeats from Flutter and from the other failure paths make no second transition.
  signalFailed(exact);
  page.global.kubusPublicTakeover.fail();
  page.bootstrapScript.dispatch('error', { type: 'error' });
  page.global.dispatchEvent({
    type: 'error',
    target: new page.global.HTMLScriptElement('https://app.kubus.site/flutter_bootstrap.js'),
  });
  assert.equal(page.marks.filter((name) => name === 'flutter_takeover_failed').length, 1);
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.reloadCount, 0, 'failure never retries automatically');

  page.dispatchEntity(exact);
  assert.equal(page.classes.has('kubus-takeover-active'), false,
    'a late ready signal cannot cover a failed SSR page');
});

test('a failed-entity signal after the exact entity is ready changes nothing', () => {
  const page = harness('en');
  const exact = { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'en' };
  page.dispatchEntity(exact);
  assert.equal(page.classes.has('kubus-takeover-active'), true);

  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-failed', { detail: exact }));
  assert.equal(page.status.dataset.state, 'ready');
  assert.equal(page.classes.has('kubus-takeover-active'), true);
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
  assert.equal(page.refreshButton.hidden, true);
});

test('a resolved not-found signal removes the overlay without the failed state', () => {
  const page = harness('en');
  const exact = { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'en' };
  const signalResolved = (detail) => page.global.dispatchEvent(
    new page.global.CustomEvent('kubus:public-entity-resolved', { detail }),
  );
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.advance(8000);
  assert.equal(page.status.dataset.state, 'slow');

  signalResolved({ ...exact, id: 'other' });
  assert.equal(page.status.dataset.state, 'slow', 'another entity cannot resolve this takeover');
  assert.equal(page.classes.has('kubus-takeover-active'), false);

  signalResolved(JSON.stringify(exact));
  assert.equal(page.status.dataset.state, 'resolved');
  assert.equal(page.status.hidden, true);
  assert.equal(page.classes.has('kubus-takeover-active'), true, 'the app is handed the page');
  assert.equal(page.classes.has('kubus-takeover-complete'), true);
  assert.equal(page.attrs.get('document:aria-hidden'), 'true');
  assert.equal(page.refreshButton.hidden, true, 'a not-found answer offers no Refresh');
  assert.equal(page.marks.includes('public_entity_resolved'), true);
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);

  // Nothing after a resolved answer can turn it into a failure or a ready state.
  page.global.kubusPublicTakeover.fail();
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-failed', { detail: exact }));
  page.dispatchEntity(exact);
  signalResolved(exact);
  assert.equal(page.status.dataset.state, 'resolved');
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
  assert.equal(page.marks.includes('public_entity_ready'), false);
  assert.equal(page.reloadCount, 0, 'the not-found answer never reloads');
});

test('a resolved signal after the exact entity is ready changes nothing', () => {
  const page = harness('en');
  const exact = { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'en' };
  page.dispatchEntity(exact);
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-resolved', { detail: exact }));
  assert.equal(page.status.dataset.state, 'ready');
  assert.equal(page.marks.includes('public_entity_resolved'), false);
});
