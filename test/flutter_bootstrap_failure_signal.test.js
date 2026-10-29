'use strict';

// A failed engine start must reach the takeover controller. When only canvaskit.wasm fails, the Flutter loader rejects
// detached promises that no catch handler in flutter_bootstrap.js sees; the template listens for those until the engine
// is ready, and bounds a request that simply hangs. Unrelated rejections must never count.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const SOURCE = fs.readFileSync(path.join(__dirname, '..', 'web', 'flutter_bootstrap.js'), 'utf8');

function run({ entityPage = true } = {}) {
  const state = { fails: 0, ready: 0, loaderOptions: null, listeners: {}, timers: [], cleared: [] };
  const source = SOURCE
    .replace('{{flutter_js}}', '')
    .replace('{{flutter_build_config}}', '')
    .replace('{{flutter_service_worker_version}}', '"sw-1"');
  const sandbox = {
    _flutter: { buildConfig: { engineRevision: 'rev' }, loader: { load: (options) => { state.loaderOptions = options; return new Promise(() => {}); } } },
    document: { readyState: 'complete', getElementById: (id) => (entityPage && id === 'kubus-public-entity-bootstrap' ? {} : null) },
    setTimeout: (fn, ms) => { state.timers.push({ fn, ms, id: state.timers.length + 1 }); return state.timers.length; },
    clearTimeout: (id) => { state.cleared.push(id); },
    requestIdleCallback: (fn) => { fn(); },
    addEventListener: (name, fn) => { (state.listeners[name] ||= []).push(fn); },
    removeEventListener: (name, fn) => { state.listeners[name] = (state.listeners[name] || []).filter((x) => x !== fn); },
    kubusPublicTakeover: entityPage ? { bootstrapStarted() {}, hostElement: () => null, engineReady: () => { state.ready += 1; }, fail: () => { state.fails += 1; } } : undefined,
  };
  sandbox.globalThis = sandbox;
  vm.runInNewContext(source, sandbox);
  // The engine start is gated on the document having painted: release it like the page would.
  for (const t of state.timers.filter((x) => x.ms === 150)) t.fn();
  state.reject = (reason) => { for (const fn of [...(state.listeners.unhandledrejection || [])]) fn({ reason }); };
  state.ceiling = () => state.timers.find((x) => x.ms === 150000);
  return state;
}

const rejection = (message, stack = '') => Object.assign(new TypeError(message), { stack });

test('a CanvasKit asset rejection before the engine is ready fails the takeover once', () => {
  const s = run();
  assert.ok(s.loaderOptions, 'engine start was called');
  s.reject(rejection("Failed to execute 'compile' on 'WebAssembly': HTTP status code is not ok"));
  assert.equal(s.fails, 1);
  s.reject(rejection('Failed to fetch', 'at k (http://x/flutter_bootstrap.js:6:1689)'));
  assert.equal(s.fails, 1, 'the watch is removed after the first failure');
});

test('a loader fetch rejection raised from the bootstrap file fails the takeover', () => {
  const s = run();
  s.reject(rejection('Failed to fetch', 'TypeError: Failed to fetch\n    at k (http://localhost/flutter_bootstrap.js:6:1689)'));
  assert.equal(s.fails, 1);
});

test('unrelated rejections, including service worker ones, never fail the takeover', () => {
  const s = run();
  s.reject(rejection('boom', 'at somewhere (http://x/analytics.js:1:1)'));
  s.reject('a plain string');
  s.reject(rejection('Failed to register a ServiceWorker', 'at k (http://x/flutter_bootstrap.js:6:1)'));
  assert.equal(s.fails, 0);
});

test('once the engine is ready the watch is gone: later rejections do nothing', async () => {
  const s = run();
  await s.loaderOptions.onEntrypointLoaded({ initializeEngine: async () => ({ runApp: async () => {} }) });
  assert.equal(s.ready, 1);
  s.reject(rejection("Failed to execute 'compile' on 'WebAssembly': nope"));
  assert.equal(s.fails, 0);
  assert.ok(s.cleared.includes(s.ceiling().id), 'the ceiling timer was cleared');
});

test('a synchronous engine failure still fails exactly once and stops the watch', async () => {
  const s = run();
  await s.loaderOptions.onEntrypointLoaded({ initializeEngine: async () => { throw new Error('init failed'); } });
  assert.equal(s.fails, 1);
  s.reject(rejection('Failed to fetch', 'at k (http://x/flutter_bootstrap.js:6:1)'));
  assert.equal(s.fails, 1);
});

test('a start that only hangs is failed by the 150 s ceiling, never reported ready', () => {
  const s = run();
  const ceiling = s.ceiling();
  assert.ok(ceiling, 'a 150 s ceiling exists');
  assert.equal(s.fails, 0);
  ceiling.fn();
  assert.equal(s.fails, 1);
  assert.equal(s.ready, 0, 'no fake readiness');
});

test('an app route (no takeover) installs nothing and cannot throw', () => {
  const s = run({ entityPage: false });
  assert.ok(s.loaderOptions);
  assert.equal((s.listeners.unhandledrejection || []).length, 0);
  assert.equal(s.ceiling(), undefined);
});
