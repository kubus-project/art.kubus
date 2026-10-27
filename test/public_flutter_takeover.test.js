const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const ORIGIN = 'https://app.kubus.site';
const TAKEOVER_JS = path.join(__dirname, '..', 'web', 'public_flutter_takeover.js');
const SEO_PROXY = path.join(__dirname, '..', 'web', 'seo-proxy.php');

const COPY = {
  en: {
    loading: 'The world of art is coming into focus…',
    failure: "The world of art couldn't open this time. Try refreshing the page or come back later.",
    retry: 'Retry',
    app: 'Go to app',
  },
  sl: {
    loading: 'Svet umetnosti se izrisuje …',
    failure: 'Svet umetnosti se tokrat ni mogel odpreti. Poskusite osvežiti stran ali se vrnite pozneje.',
    retry: 'Poskusi znova',
    app: 'Pojdi v aplikacijo',
  },
};

// A small DOM: tree, attributes, dataset, events, and the selector forms the takeover script uses
// (an optional tag followed by [attr] / [attr="v"] / [attr*="v"] clauses). Anything else throws,
// so an unsupported selector fails loudly instead of matching nothing.
const dataName = (prop) => `data-${prop.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)}`;

function* descendants(node) {
  for (const child of node.children) {
    yield child;
    yield* descendants(child);
  }
}

function matchesSelector(node, selector) {
  const tag = /^[a-z][a-z0-9]*/i.exec(selector);
  let rest = selector.slice(tag ? tag[0].length : 0);
  if (tag && node.localName !== tag[0].toLowerCase()) return false;
  const clause = /^\[([\w-]+)(?:(\*?=)"([^"]*)")?\]/;
  while (rest.length > 0) {
    const match = clause.exec(rest);
    if (!match) throw new Error(`unsupported selector in test DOM: ${selector}`);
    rest = rest.slice(match[0].length);
    const [, name, op, value] = match;
    if (!node.attributes.has(name)) return false;
    const actual = node.attributes.get(name);
    if (op === '=' && actual !== value) return false;
    if (op === '*=' && !actual.includes(value)) return false;
  }
  return true;
}

function detach(node) {
  if (!node.parentNode) return;
  const siblings = node.parentNode.children;
  const index = siblings.indexOf(node);
  if (index !== -1) siblings.splice(index, 1);
  node.parentNode = null;
}

class FakeElement {
  constructor(tagName) {
    this.localName = tagName.toLowerCase();
    this.attributes = new Map();
    this.children = [];
    this.parentNode = null;
    this.textContent = '';
    this.inert = false;
    this.style = {};
    this.listeners = new Map();
    this.classes = new Set();
    this.classList = {
      add: (...names) => names.forEach((name) => this.classes.add(name)),
      remove: (...names) => names.forEach((name) => this.classes.delete(name)),
      contains: (name) => this.classes.has(name),
    };
    const element = this;
    this.dataset = new Proxy({}, {
      get: (_, prop) => element.getAttribute(dataName(prop)) ?? undefined,
      set: (_, prop, value) => {
        element.setAttribute(dataName(prop), String(value));
        return true;
      },
    });
  }

  get hidden() { return this.attributes.has('hidden'); }
  set hidden(value) { if (value) this.attributes.set('hidden', ''); else this.attributes.delete('hidden'); }
  get disabled() { return this.attributes.has('disabled'); }
  set disabled(value) { if (value) this.attributes.set('disabled', ''); else this.attributes.delete('disabled'); }
  get src() { return this.getAttribute('src') || ''; }
  get firstChild() { return this.children[0] || null; }
  get nextSibling() {
    if (!this.parentNode) return null;
    const siblings = this.parentNode.children;
    return siblings[siblings.indexOf(this) + 1] || null;
  }

  getAttribute(name) { return this.attributes.has(name) ? this.attributes.get(name) : null; }
  setAttribute(name, value) { this.attributes.set(name, String(value)); }
  removeAttribute(name) { this.attributes.delete(name); }

  insertBefore(node, reference) {
    detach(node);
    node.parentNode = this;
    const index = reference ? this.children.indexOf(reference) : -1;
    if (index === -1) this.children.push(node);
    else this.children.splice(index, 0, node);
    return node;
  }

  appendChild(node) { return this.insertBefore(node, null); }
  remove() { detach(this); }

  querySelector(selector) {
    for (const node of descendants(this)) {
      if (matchesSelector(node, selector)) return node;
    }
    return null;
  }

  addEventListener(name, callback) {
    this.listeners.set(name, [...(this.listeners.get(name) || []), callback]);
  }

  removeEventListener(name, callback) {
    this.listeners.set(name, (this.listeners.get(name) || []).filter((item) => item !== callback));
  }

  fire(type, init = {}) {
    const event = { type, target: this, ...init };
    (this.listeners.get(type) || []).forEach((callback) => callback(event));
  }

  click() { this.fire('click'); }
}

class FakeScriptElement extends FakeElement {
  constructor(src) {
    super('script');
    this.setAttribute('src', src);
  }
}

class FakeDocument {
  constructor() {
    this.documentElement = new FakeElement('html');
    this.readyState = 'interactive';
    this.listeners = new Map();
  }

  getElementById(id) {
    for (const node of descendants(this.documentElement)) {
      if (node.getAttribute('id') === id) return node;
    }
    return null;
  }

  querySelector(selector) { return this.documentElement.querySelector(selector); }
  createElement(tagName) { return new FakeElement(tagName); }

  addEventListener(name, callback) {
    this.listeners.set(name, [...(this.listeners.get(name) || []), callback]);
  }

  fire(name) {
    (this.listeners.get(name) || []).forEach((callback) => callback({ type: name, target: this }));
  }
}

function element(tagName, attributes = {}, text = '') {
  const node = new FakeElement(tagName);
  for (const [name, value] of Object.entries(attributes)) node.setAttribute(name, value);
  node.textContent = text;
  return node;
}

// The status section as the backend renders it (contract markup).
function backendStatus(locale, { appHref = `/map?lang=${locale}` } = {}) {
  const copy = COPY[locale];
  const section = element('div', {
    id: 'flutter-takeover-status',
    'data-kubus-takeover-status': '',
    'data-state': 'pending',
    'data-locale': locale,
    'data-loading-text': copy.loading,
    'data-failure-text': copy.failure,
    'data-refresh-label': copy.retry,
    'data-app-label': copy.app,
    'data-app-href': appHref,
    hidden: '',
  });
  section.appendChild(element('span', {
    'data-kubus-takeover-message': '', role: 'status', 'aria-live': 'polite', 'aria-atomic': 'true',
  }, copy.loading));
  const actions = element('span', { class: 'takeover-actions', 'data-kubus-takeover-actions': '' });
  actions.appendChild(element('button', { type: 'button', 'data-kubus-takeover-refresh': '' }, copy.retry));
  actions.appendChild(element('a', { 'data-kubus-takeover-app': '', href: `/map?lang=${locale}` }, copy.app));
  section.appendChild(actions);
  return section;
}

// Markup from before this change: a Refresh button directly in the section, no actions group.
function oldBackendStatus(locale) {
  const label = locale === 'sl' ? 'Osveži' : 'Refresh';
  const section = element('div', {
    id: 'flutter-takeover-status',
    'data-kubus-takeover-status': '',
    'data-state': 'pending',
    'data-locale': locale,
    'data-loading-text': COPY[locale].loading,
    'data-failure-text': COPY[locale].failure,
    'data-refresh-label': label,
    hidden: '',
  });
  section.appendChild(element('span', { 'data-kubus-takeover-message': '' }));
  section.appendChild(element('button', { type: 'button', 'data-kubus-takeover-refresh': '', hidden: '' }, label));
  return section;
}

function pathFor(locale) {
  return `/${locale}/${locale === 'sl' ? 'umetnine' : 'artworks'}/art-1`;
}

function exactEntity(locale) {
  return { type: 'artwork', id: 'art-1', path: pathFor(locale), locale };
}

function countAll(node, selector) {
  let count = 0;
  for (const child of descendants(node)) {
    if (matchesSelector(child, selector)) count += 1;
  }
  return count;
}

// options: status ('current' | 'old' | 'none'), header (default true), appHref, bootstrapElement,
// resourceEntries, readyState, path.
function buildPage(locale = 'en', options = {}) {
  const doc = new FakeDocument();
  const html = doc.documentElement;
  const entityPath = options.path || pathFor(locale);

  const body = element('body');
  const publicDocument = element('div', { id: 'public-document' });
  if (options.header !== false) publicDocument.appendChild(element('header'));
  const statusMode = options.status || 'current';
  if (statusMode === 'current') publicDocument.appendChild(backendStatus(locale, { appHref: options.appHref }));
  if (statusMode === 'old') publicDocument.appendChild(oldBackendStatus(locale));
  publicDocument.appendChild(element('main', {}, 'SSR content'));
  body.appendChild(publicDocument);

  const host = element('div', {
    id: 'flutter-host',
    'aria-hidden': 'true',
    'data-entity-type': 'artwork',
    'data-entity-id': 'art-1',
    'data-entity-path': entityPath,
    'data-locale': locale,
  });
  body.appendChild(host);

  let bootstrapScript = null;
  if (options.bootstrapElement) {
    bootstrapScript = new FakeScriptElement(`${ORIGIN}/flutter_bootstrap.js`);
    body.appendChild(bootstrapScript);
  }
  html.appendChild(body);
  doc.readyState = options.readyState || 'interactive';

  const listeners = new Map();
  const timers = new Map();
  const marks = [];
  const resourceEntries = options.resourceEntries || [];
  let currentTime = 0;
  let nextTimerId = 0;
  let reloadCount = 0;

  const global = {
    document: doc,
    location: {
      pathname: entityPath,
      href: `${ORIGIN}${entityPath}`,
      origin: ORIGIN,
      reload: () => { reloadCount += 1; },
    },
    performance: {
      mark: (name) => marks.push(name),
      getEntriesByType: (type) => (type === 'resource' ? resourceEntries : []),
    },
    matchMedia: () => ({ matches: options.reducedMotion !== false }),
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
    dispatchEvent(event) { (listeners.get(event.type) || []).forEach((callback) => callback(event)); },
    CustomEvent: class CustomEvent {
      constructor(type, init = {}) { this.type = type; this.detail = init.detail; }
    },
    HTMLScriptElement: FakeScriptElement,
    URL,
  };
  global.globalThis = global;
  vm.runInNewContext(fs.readFileSync(TAKEOVER_JS, 'utf8'), global, { filename: TAKEOVER_JS });

  const advance = (duration) => {
    const until = currentTime + duration;
    for (;;) {
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

  const page = {
    global,
    doc,
    host,
    publicDocument,
    bootstrapScript,
    marks,
    classes: html.classes,
    advance,
    dispatchEntity: (detail) => global.dispatchEvent(new global.CustomEvent('kubus:public-entity-ready', { detail })),
    fireDocumentEvent: (name) => doc.fire(name),
    get reloadCount() { return reloadCount; },
    get status() { return doc.querySelector('[data-kubus-takeover-status]'); },
    get statusCount() { return countAll(doc.documentElement, '[data-kubus-takeover-status]'); },
    get message() { return page.status?.querySelector('[data-kubus-takeover-message]') ?? null; },
    get actions() { return page.status?.querySelector('[data-kubus-takeover-actions]') ?? null; },
    get refreshButton() { return page.status?.querySelector('[data-kubus-takeover-refresh]') ?? null; },
    get appLink() { return page.status?.querySelector('[data-kubus-takeover-app]') ?? null; },
  };
  if (!options.skipInitialTick) advance(0);
  return page;
}

const bootstrapEntry = (responseStatus) => ({
  name: `${ORIGIN}/flutter_bootstrap.js`,
  responseStatus,
});

test('the section is visible at once in the loading state, with no 500 ms wait', () => {
  const page = buildPage('en');
  assert.equal(page.status.hidden, false);
  assert.equal(page.status.dataset.state, 'loading');
  assert.equal(page.message.textContent, COPY.en.loading);
  assert.equal(page.refreshButton.getAttribute('hidden'), null);
  page.advance(0);
  assert.equal(page.status.dataset.state, 'loading');
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.marks.includes('public_ssr_visible'), true);
});

test('engine and route readiness alone never replace the semantic document', () => {
  const page = buildPage('en');
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.global.kubusPublicTakeover.engineReady();
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-route-parsed', {
    detail: { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'en' },
  }));
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.publicDocument.getAttribute('aria-hidden'), null);
  assert.equal(page.marks.includes('public_entity_route_parsed'), true);
  assert.equal(page.status.dataset.state, 'loading');
});

test('only the exact entity, localized path, locale and current pathname can take over', () => {
  const page = buildPage('en');
  page.global.kubusPublicTakeover.bootstrapStarted();
  for (const detail of [
    { type: 'artwork', id: 'other', path: '/en/artworks/art-1', locale: 'en' },
    { type: 'artwork', id: 'art-1', path: '/en/artworks/other', locale: 'en' },
    { type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'sl' },
  ]) page.dispatchEntity(detail);
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.status.dataset.state, 'loading', 'wrong id, path or locale never settles');
  assert.equal(page.status.hidden, false);

  page.global.location.pathname = '/sl/umetnine/art-1';
  page.dispatchEntity({ type: 'artwork', id: 'art-1', path: '/en/artworks/art-1', locale: 'en' });
  assert.equal(page.classes.has('kubus-takeover-active'), false, 'a wrong current pathname never settles');
  assert.notEqual(page.status, null);

  page.global.location.pathname = '/en/artworks/art-1';
  page.dispatchEntity(exactEntity('en'));
  assert.equal(page.classes.has('kubus-takeover-active'), true);
  assert.equal(page.classes.has('kubus-takeover-complete'), true);
  assert.equal(page.publicDocument.getAttribute('aria-hidden'), 'true');
});

test('ready for the exact entity removes the status element from the document', () => {
  const page = buildPage('sl');
  page.global.kubusPublicTakeover.bootstrapStarted();
  const section = page.status;
  page.global.location.pathname = pathFor('sl');
  page.dispatchEntity(exactEntity('sl'));
  assert.equal(page.status, null);
  assert.equal(page.statusCount, 0);
  assert.equal(section.parentNode, null, 'the detached section is no longer in the page');
  assert.equal(section.dataset.state, 'ready');
  assert.equal(page.classes.has('kubus-takeover-active'), true);
  assert.equal(page.marks.includes('public_entity_ready'), true);
});

test('the eight-second slow state keeps the copy and Retry, and never fails', () => {
  const page = buildPage('sl');
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.advance(7999);
  assert.equal(page.status.dataset.state, 'loading');
  page.advance(1);
  assert.equal(page.status.dataset.state, 'slow');
  assert.equal(page.message.textContent, COPY.sl.loading);
  assert.equal(page.status.hidden, false);
  assert.equal(page.refreshButton.textContent, COPY.sl.retry);
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
});

test('actual failure keeps the SSR page, its message, Retry and Go to app, and reloads once', () => {
  const page = buildPage('sl');
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.advance(8000);
  page.global.kubusPublicTakeover.fail();
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.publicDocument.getAttribute('aria-hidden'), null);
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.message.textContent, COPY.sl.failure);
  assert.equal(page.status.hidden, false);
  assert.equal(page.refreshButton.textContent, COPY.sl.retry);
  assert.equal(page.appLink.textContent, COPY.sl.app);
  assert.equal(page.appLink.getAttribute('href'), '/map?lang=sl');
  assert.equal(page.reloadCount, 0, 'failure never retries automatically');

  page.refreshButton.click();
  assert.equal(page.reloadCount, 1);
  assert.equal(page.refreshButton.disabled, true, 'Retry disables itself after the click');
  page.refreshButton.click();
  assert.equal(page.reloadCount, 1, 'a repeated activation never reloads twice');

  page.dispatchEntity(exactEntity('sl'));
  assert.equal(page.classes.has('kubus-takeover-active'), false,
    'a late ready signal cannot cover a failed SSR page');
});

test('a resource error after engine readiness enters the failed state', () => {
  const page = buildPage('en');
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.global.kubusPublicTakeover.engineReady();
  page.global.dispatchEvent({
    type: 'error',
    target: new page.global.HTMLScriptElement('https://app.kubus.site/canvaskit/chromium/canvaskit.js'),
  });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.refreshButton.hidden, false);
});

test('a Flutter bootstrap script error enters failure before engine readiness', () => {
  const page = buildPage('en');
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.global.dispatchEvent({
    type: 'error',
    target: new page.global.HTMLScriptElement('https://app.kubus.site/flutter_bootstrap.js'),
  });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.refreshButton.getAttribute('hidden'), null);
  assert.equal(page.reloadCount, 0);
});

test('a bootstrap element error alone, with no window capture event, enters failure', () => {
  const page = buildPage('en', { bootstrapElement: true });
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.bootstrapScript.fire('error', { type: 'error' });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.message.textContent, COPY.en.failure);
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.reloadCount, 0, 'failure never retries automatically');
});

test('window capture and bootstrap element signals for one request make a single failure transition', () => {
  for (const order of [['window', 'element'], ['element', 'window']]) {
    const page = buildPage('en', { bootstrapElement: true });
    page.global.kubusPublicTakeover.bootstrapStarted();
    const fireWindow = () => page.global.dispatchEvent({
      type: 'error',
      target: new page.global.HTMLScriptElement('https://app.kubus.site/flutter_bootstrap.js'),
    });
    const fireElement = () => page.bootstrapScript.fire('error', { type: 'error' });
    for (const signal of order) (signal === 'window' ? fireWindow : fireElement)();
    fireWindow();
    fireElement();
    assert.equal(page.status.dataset.state, 'failed', order.join(' then '));
    assert.equal(page.marks.filter((name) => name === 'flutter_takeover_failed').length, 1,
      `one failure mark for ${order.join(' then ')}`);
    assert.equal(page.reloadCount, 0);
  }
});

test('a bootstrap request that failed before the takeover script ran enters failure (Firefox deferred ordering)', () => {
  const page = buildPage('en', { bootstrapElement: true, resourceEntries: [bootstrapEntry(0)] });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.status.hidden, false);
  assert.equal(page.refreshButton.textContent, COPY.en.retry);
  assert.equal(page.classes.has('kubus-takeover-active'), false);
  assert.equal(page.reloadCount, 0);
});

test('an HTTP error response for the bootstrap request enters failure with the Slovene labels', () => {
  const page = buildPage('sl', { bootstrapElement: true, resourceEntries: [bootstrapEntry(404)] });
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.refreshButton.textContent, COPY.sl.retry);
  assert.equal(page.appLink.textContent, COPY.sl.app);
});

test('a successful status-200 bootstrap entry never fails, before or after DOMContentLoaded', () => {
  const page = buildPage('en', { bootstrapElement: true, resourceEntries: [bootstrapEntry(200)], readyState: 'loading' });
  assert.equal(page.status.dataset.state, 'loading');
  page.fireDocumentEvent('DOMContentLoaded');
  assert.equal(page.status.dataset.state, 'loading');
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
  assert.equal(page.reloadCount, 0);
});

test('an undefined responseStatus (older browsers) never fails the takeover', () => {
  const page = buildPage('en', { bootstrapElement: true, resourceEntries: [bootstrapEntry(undefined)], readyState: 'loading' });
  assert.equal(page.status.dataset.state, 'loading');
  page.fireDocumentEvent('DOMContentLoaded');
  assert.equal(page.status.dataset.state, 'loading');
  page.global.kubusPublicTakeover.bootstrapStarted();
  page.advance(8000);
  assert.equal(page.status.dataset.state, 'slow');
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
  assert.equal(page.reloadCount, 0);
});

test('a pending bootstrap request with its script present never fails the takeover', () => {
  const page = buildPage('en', { bootstrapElement: true, resourceEntries: [], readyState: 'loading' });
  page.fireDocumentEvent('DOMContentLoaded');
  assert.equal(page.status.dataset.state, 'loading');
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
});

test('a request that fails after the takeover script ran is caught by the DOMContentLoaded recheck', () => {
  const entries = [];
  const page = buildPage('en', { bootstrapElement: true, resourceEntries: entries, readyState: 'loading' });
  assert.equal(page.status.dataset.state, 'loading');
  entries.push(bootstrapEntry(0));
  page.fireDocumentEvent('DOMContentLoaded');
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.marks.filter((name) => name === 'flutter_takeover_failed').length, 1);
});

test('a missing bootstrap script at DOMContentLoaded enters failure, and the SSR page stays interactive', () => {
  const page = buildPage('en', { bootstrapElement: false, readyState: 'loading' });
  assert.equal(page.status.dataset.state, 'loading', 'nothing fails before DOMContentLoaded');
  page.fireDocumentEvent('DOMContentLoaded');
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.message.textContent, COPY.en.failure);
  assert.equal(page.refreshButton.textContent, COPY.en.retry);
  assert.equal(page.publicDocument.inert, false, 'the SSR document is not made inert');
  assert.equal(page.host.inert, true);
  assert.equal(page.reloadCount, 0);
});

test('a completed bootstrap request with no script element never fails at DOMContentLoaded', () => {
  const page = buildPage('en', { bootstrapElement: false, resourceEntries: [bootstrapEntry(200)], readyState: 'loading' });
  page.fireDocumentEvent('DOMContentLoaded');
  assert.equal(page.status.dataset.state, 'loading');
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
});

test('a Flutter failed-entity signal reuses the one idempotent failure transition', () => {
  const page = buildPage('en', { bootstrapElement: true });
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
  assert.equal(page.message.textContent, COPY.en.failure);
  assert.equal(page.refreshButton.textContent, COPY.en.retry);
  assert.equal(page.classes.has('kubus-takeover-active'), false);

  // Repeats from Flutter and from the other failure paths make no second transition.
  signalFailed(exact);
  page.global.kubusPublicTakeover.fail();
  page.bootstrapScript.fire('error', { type: 'error' });
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

test('a failed-entity signal after the exact entity is ready changes nothing and throws nothing', () => {
  const page = buildPage('en');
  const exact = exactEntity('en');
  page.dispatchEntity(exact);
  assert.equal(page.classes.has('kubus-takeover-active'), true);
  assert.equal(page.status, null);

  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-failed', { detail: exact }));
  page.global.kubusPublicTakeover.fail();
  page.global.kubusPublicTakeover.engineReady();
  page.bootstrapScript?.fire('error', { type: 'error' });
  assert.equal(page.classes.has('kubus-takeover-active'), true);
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
  assert.equal(page.status, null);
});

test('a resolved not-found signal removes the overlay without the failed state or Retry', () => {
  const page = buildPage('en');
  const exact = exactEntity('en');
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
  assert.equal(page.status, null, 'the section is removed on handoff');
  assert.equal(page.classes.has('kubus-takeover-active'), true, 'the app is handed the page');
  assert.equal(page.classes.has('kubus-takeover-complete'), true);
  assert.equal(page.publicDocument.getAttribute('aria-hidden'), 'true');
  assert.equal(page.marks.includes('public_entity_resolved'), true);
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);

  // Nothing after a resolved answer can turn it into a failure or a ready state.
  page.global.kubusPublicTakeover.fail();
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-failed', { detail: exact }));
  page.dispatchEntity(exact);
  signalResolved(exact);
  assert.equal(page.marks.includes('flutter_takeover_failed'), false);
  assert.equal(page.marks.includes('public_entity_ready'), false);
  assert.equal(page.reloadCount, 0, 'the not-found answer never reloads');
});

test('a resolved signal after the exact entity is ready changes nothing', () => {
  const page = buildPage('en');
  const exact = exactEntity('en');
  page.dispatchEntity(exact);
  page.global.dispatchEvent(new page.global.CustomEvent('kubus:public-entity-resolved', { detail: exact }));
  assert.equal(page.marks.includes('public_entity_resolved'), false);
  assert.equal(page.marks.includes('public_entity_ready'), true);
});

test('Go to app defaults to the locale map route for en and sl, in both the backend and PHP paths', () => {
  for (const locale of ['en', 'sl']) {
    const backend = buildPage(locale);
    assert.equal(backend.appLink.getAttribute('href'), `/map?lang=${locale}`);
    const gateway = buildPage(locale, { status: 'none' });
    assert.equal(gateway.appLink.getAttribute('href'), `/map?lang=${locale}`);
    assert.equal(gateway.appLink.textContent, COPY[locale].app);
  }
});

test('Go to app keeps a safe same-origin path from the markup', () => {
  const page = buildPage('en', { appHref: '/community?lang=en' });
  assert.equal(page.appLink.getAttribute('href'), '/community?lang=en');
});

test('Go to app rejects protocol-relative, absolute, non-path and own-entity addresses', () => {
  const unsafe = [
    '//evil.example/map',
    '/\\evil.example/map',
    'https://evil.example/map',
    'http://evil.example/',
    'javascript:alert(1)',
    'relative/map',
    '/en/artworks/art-1',
    '/en/artworks/art-1/',
    '/en/artworks/art-1?lang=sl#top',
    '/map\nX',
    '',
  ];
  for (const raw of unsafe) {
    const page = buildPage('en', { appHref: raw });
    assert.equal(page.appLink.getAttribute('href'), '/map?lang=en', `rejected ${JSON.stringify(raw)}`);
  }
});

test('an old-backend section (no actions group, Refresh label) gets the actions and still takes over', () => {
  const page = buildPage('en', { status: 'old', bootstrapElement: true });
  assert.equal(page.statusCount, 1, 'no duplicate section is created');
  assert.equal(page.status.dataset.state, 'loading');
  assert.equal(page.status.hidden, false);
  assert.notEqual(page.actions, null, 'the actions group is added');
  assert.equal(page.refreshButton.parentNode, page.actions, 'Refresh moves into the actions group');
  assert.equal(page.appLink.parentNode, page.actions);
  assert.equal(page.refreshButton.textContent, 'Refresh', 'the old label is kept');
  assert.equal(page.refreshButton.getAttribute('hidden'), null);
  assert.equal(page.appLink.getAttribute('href'), '/map?lang=en');
  assert.equal(page.message.textContent, COPY.en.loading, 'the loading state fills the message');

  page.global.kubusPublicTakeover.bootstrapStarted();
  page.dispatchEntity(exactEntity('en'));
  assert.equal(page.status, null);
  assert.equal(page.classes.has('kubus-takeover-active'), true);
});

test('the PHP gateway path (no section in the page) gets one section, placed after the header', () => {
  const page = buildPage('en', { status: 'none', bootstrapElement: true });
  assert.equal(page.statusCount, 1);
  const section = page.status;
  assert.equal(section.parentNode, page.publicDocument);
  const header = page.publicDocument.querySelector('header');
  assert.equal(section.parentNode.children[section.parentNode.children.indexOf(header) + 1], section);
  assert.equal(section.dataset.locale, 'en');
  assert.equal(section.dataset.state, 'loading');
  assert.equal(page.message.textContent, COPY.en.loading);
  assert.equal(page.refreshButton.textContent, COPY.en.retry);
  assert.equal(page.appLink.textContent, COPY.en.app);
});

test('the PHP gateway path with no header inserts the section as the first child of the public document', () => {
  const page = buildPage('sl', { status: 'none', header: false });
  assert.equal(page.statusCount, 1);
  assert.equal(page.publicDocument.firstChild, page.status);
});

test('an existing section is never duplicated, including on a repeated timer and a failure', () => {
  for (const status of ['current', 'old']) {
    const page = buildPage('en', { status, bootstrapElement: true });
    assert.equal(page.statusCount, 1);
    page.global.kubusPublicTakeover.bootstrapStarted();
    page.advance(8000);
    page.global.kubusPublicTakeover.fail();
    assert.equal(page.statusCount, 1, status);
  }
});

test('EN and SL strings for the created section', () => {
  const sl = buildPage('sl', { status: 'none' });
  assert.equal(sl.message.textContent, COPY.sl.loading);
  assert.equal(sl.refreshButton.textContent, COPY.sl.retry);
  assert.equal(sl.appLink.textContent, COPY.sl.app);
  sl.global.kubusPublicTakeover.fail();
  assert.equal(sl.message.textContent, COPY.sl.failure);

  const en = buildPage('en', { status: 'none' });
  assert.equal(en.message.textContent, COPY.en.loading);
  assert.equal(en.refreshButton.textContent, COPY.en.retry);
  assert.equal(en.appLink.textContent, COPY.en.app);
  en.global.kubusPublicTakeover.fail();
  assert.equal(en.message.textContent, COPY.en.failure);
});

test('the Slovene section copy is the one the gateway emits (static parity)', () => {
  const js = fs.readFileSync(TAKEOVER_JS, 'utf8');
  const php = fs.readFileSync(SEO_PROXY, 'utf8');
  for (const locale of ['en', 'sl']) {
    for (const key of ['loading', 'failure', 'retry', 'app']) {
      assert.ok(js.includes(COPY[locale][key]), `takeover script has ${locale} ${key}`);
      assert.ok(php.includes(COPY[locale][key]), `gateway has ${locale} ${key}`);
    }
  }
});

test('the takeover script never leaves a failed section without its actions', () => {
  const js = fs.readFileSync(TAKEOVER_JS, 'utf8');
  assert.doesNotMatch(js, /refreshButton\.hidden/, 'visibility is the section, not the button');
  assert.doesNotMatch(js, /setTimeout\([^)]*,\s*500\)/, 'no 500 ms delay before the loading state');
  assert.match(js, /location\.reload\(\)/);
  assert.match(js, /kubus:public-entity-ready/);
  assert.match(js, /publicDocument\.inert = true/);
  assert.match(js, /getEntriesByType\?\.\("resource"\)/);
});

test('PHP gateway: the host carries data-locale and the section is injected only once', () => {
  const gateway = fs.readFileSync(SEO_PROXY, 'utf8');
  assert.match(gateway, /data-entity-path="' \. \$path \. '" data-locale="' \. takeoverEscape\(\$locale\) \. '"><\/div>/);
  assert.match(gateway, /\$needsStatus = stripos\(\$html, 'data-kubus-takeover-status'\) === false;/);
  assert.match(gateway, /if \(\$needsStatus\) \{/);
  assert.match(gateway, /\$html = substr\(\$html, 0, \$insertAt\) \. takeoverStatusMarkup\(\$locale\) \. substr\(\$html, \$insertAt\);/);
});

test('PHP gateway: the locale comes from the path and is validated to en or sl', () => {
  const gateway = fs.readFileSync(SEO_PROXY, 'utf8');
  assert.match(gateway, /'locale' => \$locale,/);
  assert.match(gateway, /if \(!in_array\(\$locale, \['en', 'sl'\], true\)\) \{\s*return null;/);
  assert.match(gateway, /\$locale = \$matches\[1\];/);
});

test('PHP gateway: an existing host passes through unchanged', () => {
  const gateway = fs.readFileSync(SEO_PROXY, 'utf8');
  assert.match(gateway, /if \(stripos\(\$html, 'id="flutter-host"'\) !== false \|\| stripos\(\$html, "id='flutter-host'"\) !== false\) \{\s*return \$html;/);
});

test('PHP gateway: the section is placed after the first header, else first in the public document', () => {
  const gateway = fs.readFileSync(SEO_PROXY, 'utf8');
  assert.match(gateway, /\$headerEnd = stripos\(\$html, '<\/header>', \$insertAt\);/);
  assert.match(gateway, /\$insertAt = \$headerEnd \+ strlen\('<\/header>'\);/);
});

test('PHP gateway: the section markup carries the backend contract attributes and the Go to app route', () => {
  const gateway = fs.readFileSync(SEO_PROXY, 'utf8');
  const markup = /function takeoverStatusMarkup[\s\S]*?\r?\n}\r?\n/.exec(gateway);
  assert.ok(markup, 'takeoverStatusMarkup exists');
  for (const fragment of [
    'id="flutter-takeover-status"',
    'data-kubus-takeover-status',
    'data-state="pending"',
    'data-kubus-takeover-message role="status" aria-live="polite" aria-atomic="true"',
    'takeover-actions" data-kubus-takeover-actions',
    'data-kubus-takeover-refresh>',
    'data-kubus-takeover-app href="',
    "'/map?lang=' . $locale",
    '" hidden>',
  ]) {
    assert.ok(markup[0].includes(fragment), `markup has ${fragment}`);
  }
});

test('PHP gateway: the status CSS has no reserved height, no visibility hiding, and no opacity; focus and touch sizes hold', () => {
  const gateway = fs.readFileSync(SEO_PROXY, 'utf8');
  const css = /const KUBUS_TAKEOVER_STATUS_CSS = ([\s\S]*?);\r?\n/.exec(gateway);
  assert.ok(css, 'status CSS constant exists');
  const block = css[1];
  assert.doesNotMatch(block, /height:\s*min\(8rem/);
  assert.doesNotMatch(block, /visibility:\s*hidden/);
  assert.doesNotMatch(block, /opacity/);
  assert.match(block, /#flutter-takeover-status\[hidden\]\{display:none\}/);
  assert.match(block, /outline:3px solid var\(--color-focus/);
  assert.match(block, /min-height:2\.75rem/);
  assert.match(block, /flex:1 1 16rem/);
  assert.match(block, /flex-wrap:wrap/);
  assert.match(block, /@media\(max-width:420px\)/);
  assert.match(gateway, /KUBUS_TAKEOVER_STATUS_CSS \. '<\/style>'/);
});

test('Retry is re-enabled after the reset timeout when no reload happened', () => {
  const page = buildPage('en');
  page.global.kubusPublicTakeover.fail();
  page.refreshButton.click();
  assert.equal(page.refreshButton.disabled, true);
  page.advance(3999);
  assert.equal(page.refreshButton.disabled, true, 'still disabled inside the 4 s window');
  page.advance(1);
  assert.equal(page.refreshButton.disabled, false, 're-enabled at 4 s');
  page.refreshButton.click();
  assert.equal(page.reloadCount, 2, 'a new activation reloads again');
});

test('Retry is re-enabled by pageshow, for a cancelled reload or a back-forward cache restore', () => {
  const page = buildPage('en');
  page.global.kubusPublicTakeover.fail();
  page.refreshButton.click();
  assert.equal(page.refreshButton.disabled, true);
  page.global.dispatchEvent({ type: 'pageshow', persisted: true });
  assert.equal(page.refreshButton.disabled, false);
  page.refreshButton.click();
  assert.equal(page.reloadCount, 2);
});

test('handoff keeps the section box (visibility only) during the fade, then removes it, one section throughout', () => {
  const page = buildPage('en', { reducedMotion: false, bootstrapElement: true });
  page.global.kubusPublicTakeover.bootstrapStarted();
  assert.equal(page.statusCount, 1);
  const section = page.status;
  page.dispatchEntity(exactEntity('en'));
  assert.equal(page.classes.has('kubus-takeover-active'), true);
  assert.equal(page.classes.has('kubus-takeover-complete'), false, 'the fade is still running');
  assert.equal(page.status, section, 'the section stays in the document during the fade');
  assert.equal(section.style.visibility, 'hidden');
  assert.equal(section.hidden, false, 'no display change, so no layout shift');
  assert.equal(page.statusCount, 1);
  page.advance(259);
  assert.equal(page.status, section);
  page.advance(1);
  assert.equal(page.classes.has('kubus-takeover-complete'), true);
  assert.equal(page.status, null);
  assert.equal(section.parentNode, null);
  assert.equal(page.statusCount, 0);
});

test('the live message is cleared on reveal and written in the next task, in one message span', () => {
  const page = buildPage('en', { status: 'none', skipInitialTick: true });
  assert.equal(page.message.textContent, '', 'the reveal starts with an empty message');
  assert.equal(page.statusCount, 1);
  assert.equal(countAll(page.status, '[data-kubus-takeover-message]'), 1);
  page.advance(0);
  assert.equal(page.message.textContent, COPY.en.loading);
  assert.equal(countAll(page.status, '[data-kubus-takeover-message]'), 1);
});

test('a failure before the reveal text lands is not overwritten by the loading text', () => {
  const page = buildPage('en', {
    skipInitialTick: true, bootstrapElement: true, resourceEntries: [bootstrapEntry(0)],
  });
  page.advance(0);
  assert.equal(page.status.dataset.state, 'failed');
  assert.equal(page.message.textContent, COPY.en.failure);
});

test('PHP gateway: Retry uses the backend accent token names and a distinct disabled look without opacity', () => {
  const gateway = fs.readFileSync(SEO_PROXY, 'utf8');
  const css = /const KUBUS_TAKEOVER_STATUS_CSS = ([\s\S]*?);\r?\n/.exec(gateway)[1];
  assert.doesNotMatch(css, /--color-primary|--color-on-primary/);
  assert.match(css, /var\(--color-accent,/);
  assert.match(css, /var\(--color-on-accent,/);
  assert.match(css, /\[data-kubus-takeover-refresh\]:disabled\{border-style:dashed;[^}]*color:var\(--color-muted/);
  assert.doesNotMatch(css, /opacity/);
});

test('the takeover script re-enables Retry on pageshow and removes the section at the end of the fade', () => {
  const js = fs.readFileSync(TAKEOVER_JS, 'utf8');
  assert.match(js, /globalThis\.addEventListener\("pageshow", enableRetry\)/);
  assert.match(js, /root\.classList\.add\("kubus-takeover-complete"\);\s*removeStatusElement\(\);/);
});
