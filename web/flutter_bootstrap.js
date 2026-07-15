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
