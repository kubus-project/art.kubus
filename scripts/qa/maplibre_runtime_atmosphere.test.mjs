// The MapLibre runtime promise must resolve when MapLibre loads, even if the
// optional globe-atmosphere module cannot be imported. A decorative layer must
// never leave the web map on its loading backdrop.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

// RUNTIME_SOURCE_PATH lets a reviewer point the test at another revision.
const source = fs.readFileSync(
  process.env.RUNTIME_SOURCE_PATH ||
    path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../web/kubus_maplibre_runtime.js'),
  'utf8',
);

function run({ atmosphereLoads }) {
  const elements = new Map();
  const maplibregl = { setWorkerUrl() {}, installed: false };
  const document = {
    getElementById: (id) => elements.get(id) ?? null,
    createElement: () => {
      const listeners = new Map();
      return {
        dataset: {},
        addEventListener: (type, fn) => listeners.set(type, fn),
        fire: (type) => listeners.get(type)?.(),
      };
    },
    head: {
      appendChild(el) {
        if (el.id) elements.set(el.id, el);
        // Scripts "load" at once; the first one exposes maplibregl.
        if (el.src) {
          if (el.src.includes('maplibre-gl-csp.js')) context.maplibregl = maplibregl;
          queueMicrotask(() => el.fire('load'));
        }
      },
    },
  };
  const context = vm.createContext({ document, queueMicrotask, console, String, encodeURIComponent });
  context.globalThis = context;
  const script = new vm.Script(source, {
    filename: 'kubus_maplibre_runtime.js',
    importModuleDynamically: async () => {
      if (!atmosphereLoads) throw new Error('Failed to fetch dynamically imported module');
      const module = new vm.SourceTextModule(
        'export function installGlobeAtmosphere(m) { m.installed = true; }',
        { context },
      );
      await module.link(() => {});
      await module.evaluate();
      return module;
    },
  });
  script.runInContext(context);
  return { context, maplibregl };
}

test('the runtime is ready when the atmosphere module fails to load', async () => {
  const { context } = run({ atmosphereLoads: false });
  await assert.doesNotReject(context.kubusMapLibreRuntimeReady);
  assert.match(String(context.kubusGlobeAtmosphereError), /Failed to fetch/);
});
