// @ts-nocheck
// This file is a Flutter web template and contains `{{...}}` placeholders that
// are replaced during `flutter build web`. IDE TypeScript checking will flag
// those placeholders as syntax errors unless disabled.
{{flutter_js}}

{{flutter_build_config}}

// Force self-hosted CanvasKit (prevents falling back to the gstatic CDN).
_flutter.buildConfig.useLocalCanvasKit = true;

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    // MapLibre (web) uses maplibre-gl-js (WebGL).
    //
    // We *prefer* the HTML renderer to reduce the risk of CanvasKit+WASM/WebGL
    // compositing crashes seen in production (e.g. canvaskit.wasm
    // "index out of bounds").
    //
    // IMPORTANT:
    // - On Flutter 3.38+ the loader selects between the *builds* emitted into
    //   the web bundle (commonly CanvasKit, and optionally skwasm when building
    //   with `--wasm`).
    // - The loader can only select renderers that exist in `_flutter.buildConfig.builds`.
    //   Forcing a renderer that is not present will prevent the app from loading.
    //
    // If the current bundle does not include an HTML build, do not force it
    // (forcing a missing renderer causes:
    //   "FlutterLoader could not find a build compatible...").
    renderer: (() => {
      try {
        const builds = (_flutter?.buildConfig?.builds ?? []).filter(Boolean);
        const hasHtml = builds.some((b) => b && b.renderer === 'html');
        return hasHtml ? 'html' : undefined;
      } catch (_) {
        return undefined;
      }
    })(),
  },
});
