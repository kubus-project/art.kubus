(function () {
  "use strict";

  if (globalThis.kubusMapLibreRuntimeReady) {
    return;
  }

  const buildVersion = encodeURIComponent(
    String(globalThis.__kubusBuildVersion || "dev"),
  );
  const ensureStyles = () => {
    if (document.getElementById("kubus-maplibre-runtime-styles")) return;
    const stylesheet = document.createElement("link");
    stylesheet.id = "kubus-maplibre-runtime-styles";
    stylesheet.rel = "stylesheet";
    stylesheet.href = `/local/maplibre-gl/maplibre-gl.css?v=${buildVersion}`;
    document.head.appendChild(stylesheet);
  };

  const loadScript = (id, src) =>
    new Promise((resolve, reject) => {
      const existing = document.getElementById(id);
      if (existing) {
        if (existing.dataset.loaded === "true") {
          resolve();
          return;
        }
        existing.addEventListener("load", resolve, { once: true });
        existing.addEventListener("error", reject, { once: true });
        return;
      }

      const script = document.createElement("script");
      script.id = id;
      script.src = src;
      script.async = false;
      script.addEventListener(
        "load",
        () => {
          script.dataset.loaded = "true";
          resolve();
        },
        { once: true },
      );
      script.addEventListener("error", reject, { once: true });
      document.head.appendChild(script);
    });

  ensureStyles();
  globalThis.kubusMapLibreRuntimeReady = loadScript(
    "kubus-maplibre-runtime-script",
    `/local/maplibre-gl/maplibre-gl-csp.js?v=${buildVersion}`,
  ).then(() => {
    if (!globalThis.maplibregl) {
      throw new Error("MapLibre runtime did not expose maplibregl");
    }
    globalThis.maplibregl.setWorkerUrl(
      `/local/maplibre-gl/maplibre-gl-csp-worker.js?v=${buildVersion}`,
    );
    return loadScript(
      "kubus-webgl-context-handler",
      `/webgl_context_handler.js?v=${buildVersion}`,
    );
  });
  globalThis.kubusMapLibreRuntimeReady.catch(() => {});
})();
