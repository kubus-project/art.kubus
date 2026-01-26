{{flutter_js}}

{{flutter_build_config}}

// Force self-hosted CanvasKit (prevents falling back to the gstatic CDN).
_flutter.buildConfig.useLocalCanvasKit = true;

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    // MapLibre GL on web uses WebGL; running Flutter itself on CanvasKit (also WebGL)
    // can starve/kill the map's context on some GPUs/browsers, resulting in an
    // invisible map. HTML renderer keeps Flutter off WebGL and allows MapLibre
    // to own the WebGL context reliably.
    renderer: "html",
  },
});
