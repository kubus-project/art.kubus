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
    // MapLibre (web) uses maplibre-gl-js (WebGL). We run the Flutter app with
    // the HTML renderer to avoid CanvasKit+WASM/WebGL compositing crashes seen
    // in production (e.g. canvaskit.wasm "index out of bounds").
    //
    // IMPORTANT: Build the web bundle with `--web-renderer=html` to match.
    renderer: "html",
  },
});
