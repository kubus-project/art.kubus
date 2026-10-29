'use strict';

// The bootstrap template must let a public entity page paint its server-rendered document before the Flutter
// engine competes for the main thread, without delaying app routes and without changing what the takeover
// controller sees (the script itself still runs at once and still calls bootstrapStarted).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const SOURCE = fs.readFileSync(path.join(__dirname, '..', 'web', 'flutter_bootstrap.js'), 'utf8');

// Runs the template with the Flutter placeholders stubbed and returns what happened.
function run({ entityPage, readyState = 'loading' }) {
  const calls = { loads: 0, started: 0, timers: [], idle: [], listeners: {} };
  const source = SOURCE
    .replace('{{flutter_js}}', '')
    .replace('{{flutter_build_config}}', '')
    .replace('{{flutter_service_worker_version}}', '"sw-1"');
  const sandbox = {
    _flutter: { buildConfig: { engineRevision: 'rev' }, loader: { load: () => { calls.loads += 1; return Promise.resolve(); } } },
    document: { readyState, getElementById: (id) => (entityPage && id === 'kubus-public-entity-bootstrap' ? {} : null) },
    setTimeout: (fn, ms) => { calls.timers.push({ fn, ms }); return calls.timers.length; },
    requestIdleCallback: (fn, opts) => { calls.idle.push({ fn, opts }); },
    addEventListener: (name, fn, opts) => { calls.listeners[name] = { fn, opts }; },
    kubusPublicTakeover: { bootstrapStarted: () => { calls.started += 1; }, hostElement: () => null, engineReady() {}, fail() {} },
  };
  sandbox.globalThis = sandbox;
  vm.runInNewContext(source, sandbox);
  return calls;
}

test('an app route starts the engine immediately', () => {
  const calls = run({ entityPage: false });
  assert.equal(calls.loads, 1);
  assert.equal(calls.started, 1);
});

test('a public entity page tells the controller at once but holds the engine until the document has loaded and is idle', () => {
  const calls = run({ entityPage: true });
  assert.equal(calls.started, 1, 'bootstrapStarted is still called immediately');
  assert.equal(calls.loads, 0, 'the engine has not started');
  assert.ok(calls.listeners.load, 'waits for the load event');
  calls.listeners.load.fn();
  assert.equal(calls.idle.length, 1, 'then for an idle period');
  assert.equal(calls.loads, 0);
  calls.idle[0].fn();
  const go = calls.timers.find((t) => t.ms === 150);
  assert.ok(go, 'then a short settle delay');
  go.fn();
  assert.equal(calls.loads, 1);
});

test('the engine start is capped so a slow load event cannot hold the app back', () => {
  const calls = run({ entityPage: true });
  const cap = calls.timers.find((t) => t.ms === 6000);
  assert.ok(cap, 'a 6 s cap exists');
  cap.fn();
  assert.equal(calls.loads, 1);
  calls.listeners.load.fn();
  calls.idle[0].fn();
  calls.timers.find((t) => t.ms === 150).fn();
  assert.equal(calls.loads, 1, 'the engine is started exactly once');
});

test('a page that has already finished loading goes straight to the idle wait', () => {
  const calls = run({ entityPage: true, readyState: 'complete' });
  assert.equal(calls.idle.length, 1);
  assert.equal(calls.listeners.load, undefined);
});
