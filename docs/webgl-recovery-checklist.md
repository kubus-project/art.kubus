WebGL / MapLibre recovery manual verification
============================================

Purpose
-------
Verify that the dark/teal fallback prevents white flashes when WebGL
contexts are lost or the MapLibre canvas is recreated.

Quick manual test steps
----------------------
1. Open the app in a browser (preferably Firefox to reproduce memory-pressure
   behavior) and navigate to the Map screen.
2. Open DevTools → Console and enable logging by adding `?debug_webgl=1`
   to the URL (optional).
3. In the console, trigger a context loss on the MapLibre canvas:

   - Find the canvas element: `document.querySelector('.maplibregl-canvas')`
   - If present, call `canvas.dispatchEvent(new Event('webglcontextlost'))` or
     run code that simulates loss: `canvas.getContext('webgl')?.loseContext();`

4. Observe the map area while the context is lost and during restoration.
   Expected:
   - No bright/white flash should appear; instead the area should display
     the dark/teal Kubus fallback color (#012f2f).
   - The canvas and map container should have the `data-webgl-recovering="true"`
     attribute while recovering, and it should be cleared once restored.
5. Restore the context (if applicable) and ensure UI overlays (search, dialogs,
   buttons) remain interactive and visible above the map.

Automated smoke (optional)
--------------------------
You can script a quick smoke check in DevTools by running:

```
const c = document.querySelector('.maplibregl-canvas');
if (c) {
  c.dispatchEvent(new Event('webglcontextlost'));
  setTimeout(()=> c.dispatchEvent(new Event('webglcontextrestored')), 500);
}
```

Notes
-----
- The recovery styling is applied via `data-webgl-recovering` on the canvas and
  the `.maplibregl-map` container. The CSS ensures the fallback color is used
  and is never white.
- The solution intentionally avoids adding large opaque overlays that could
  block Flutter's overlays; instead it targets canvas/container backgrounds.
