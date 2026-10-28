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

const startEngine = () => {
  try {
    Promise.resolve(_flutter.loader.load({
      serviceWorkerSettings: {
        serviceWorkerVersion: flutterServiceWorkerVersion,
      },
      config: engineConfig,
      onEntrypointLoaded: async (engineInitializer) => {
        try {
          const appRunner = await engineInitializer.initializeEngine(engineConfig);
          takeover?.engineReady();
          await appRunner.runApp();
        } catch (_) {
          takeover?.fail();
        }
      },
    })).catch(() => takeover?.fail());
  } catch (_) {
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
