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
    // Keep this aligned with the build output. If you build with
    // `--web-renderer canvaskit`, forcing `html` here will cause:
    // "FlutterLoader could not find a build compatible with configuration..."
    renderer: "canvaskit",
    canvasKitBaseUrl: "/canvaskit/",
  },
});
