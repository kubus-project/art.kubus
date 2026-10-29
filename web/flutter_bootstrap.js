// @ts-nocheck
// This file is a Flutter web template and contains `{{...}}` placeholders that
// are replaced during `flutter build web`. IDE TypeScript checking will flag
// those placeholders as syntax errors unless disabled.
{{flutter_js}}

{{flutter_build_config}}

// Force self-hosted CanvasKit (prevents falling back to the gstatic CDN).
_flutter.buildConfig.useLocalCanvasKit = true;

const takeover = globalThis.kubusPublicTakeover;
takeover?.bootstrapStarted();
const flutterServiceWorkerVersion = {{flutter_service_worker_version}};
globalThis.__kubusBuildVersion ||= String(
  flutterServiceWorkerVersion || _flutter.buildConfig.engineRevision || "dev",
);

const engineConfig = {
  renderer: "canvaskit",
  entrypointBaseUrl: "/",
  assetBase: "/",
  canvasKitBaseUrl: "/canvaskit/",
};
const takeoverHost = takeover?.hostElement();
if (takeoverHost) {
  engineConfig.hostElement = takeoverHost;
}

// Engine start-up failures do not always reach the catch handlers below. When only canvaskit.wasm fails, the loader
// rejects detached promises (TypeError "Failed to fetch" raised from this file, or a WebAssembly "compile ... HTTP
// status code is not ok" error), so the takeover controller would show the loading state forever. Until the engine is
// ready, such a rejection is a failed start. Only rejections that name the engine's own loader or assets count;
// unrelated rejections never do. A request that merely hangs raises nothing, so a ceiling bounds it: it is far beyond
// the slowest measured start (about 56 s at 4x CPU on slow 4G) and shows the failure state with Retry, never a
// fake readiness.
const ENGINE_READY_CEILING_MS = 150000;
let stopWatchingEngineStart = () => {};
const isEngineStartupRejection = (reason) => {
  const text = String((reason && reason.message) || reason || "");
  const stack = String((reason && reason.stack) || "");
  if (/service ?worker/i.test(text)) return false;
  return /canvaskit|skwasm|WebAssembly|dynamically imported module/i.test(text) ||
    stack.includes("flutter_bootstrap.js") || stack.includes("canvaskit") || stack.includes("main.dart.js");
};
const watchEngineStart = () => {
  if (!takeover) return;
  let ceiling = null;
  const onRejection = (event) => {
    if (!isEngineStartupRejection(event.reason)) return;
    stopWatchingEngineStart();
    takeover.fail();
  };
  stopWatchingEngineStart = () => {
    globalThis.removeEventListener("unhandledrejection", onRejection);
    if (ceiling !== null) globalThis.clearTimeout(ceiling);
    ceiling = null;
  };
  globalThis.addEventListener("unhandledrejection", onRejection);
  ceiling = globalThis.setTimeout(() => {
    stopWatchingEngineStart();
    takeover.fail();
  }, ENGINE_READY_CEILING_MS);
};

const startEngine = () => {
  watchEngineStart();
  try {
    Promise.resolve(_flutter.loader.load({
      serviceWorkerSettings: {
        serviceWorkerVersion: flutterServiceWorkerVersion,
      },
      config: engineConfig,
      onEntrypointLoaded: async (engineInitializer) => {
        try {
          const appRunner = await engineInitializer.initializeEngine(engineConfig);
          stopWatchingEngineStart();
          takeover?.engineReady();
          await appRunner.runApp();
        } catch (_) {
          stopWatchingEngineStart();
          takeover?.fail();
        }
      },
    })).catch(() => {
      stopWatchingEngineStart();
      takeover?.fail();
    });
  } catch (_) {
    stopWatchingEngineStart();
    takeover?.fail();
  }
};

// A public entity page is already readable: its server-rendered document is the first paint and the LCP. Let that
// document finish loading and the main thread go idle before the engine's download, compile and boot compete for it
// (on a throttled phone they otherwise delay the LCP paint by tens of seconds). This script is still requested and
// run immediately, so the takeover controller's bootstrap checks are unchanged; only the engine start waits, and the
// wait is capped so a slow third-party resource can never hold the app back for long. App routes start at once.
const ENGINE_START_CAP_MS = 6000;
const startWhenDocumentIsPainted = (start) => {
  let started = false;
  const go = () => {
    if (started) return;
    started = true;
    start();
  };
  const afterLoad = () => {
    if (typeof globalThis.requestIdleCallback === "function") {
      globalThis.requestIdleCallback(() => globalThis.setTimeout(go, 150), { timeout: 2000 });
    } else {
      globalThis.setTimeout(go, 1000);
    }
  };
  globalThis.setTimeout(go, ENGINE_START_CAP_MS);
  if (document.readyState === "complete") {
    afterLoad();
  } else {
    globalThis.addEventListener("load", afterLoad, { once: true });
  }
};

if (document.getElementById("kubus-public-entity-bootstrap")) {
  startWhenDocumentIsPainted(startEngine);
} else {
  startEngine();
}
