import * as THREE from "three";
import { SparkRenderer, SplatMesh } from "@sparkjsdev/spark";

const canvas = document.querySelector("canvas");
const status = document.querySelector("#status");

// The web host names each load attempt in the page URL (`?a=<n>`) and drops any
// message that does not echo the current one, so a page that is being replaced
// (a timed-out tier, a retry) can never answer for the attempt that follows it.
// Native hosts load the page without it.
const attemptId = new URLSearchParams(window.location.search).get("a");

// Status channel. Native hosts expose a `SpatialViewer` JavaScript channel;
// the Flutter web host embeds this page in a same-origin iframe and receives
// the same strings as `{ kubusSpatialViewer: "<message>", attempt }` window
// messages.
function post(message) {
  try {
    if (window.SpatialViewer && window.SpatialViewer.postMessage) {
      window.SpatialViewer.postMessage(message);
    } else if (window.parent && window.parent !== window) {
      const payload = { kubusSpatialViewer: message };
      if (attemptId !== null) payload.attempt = attemptId;
      window.parent.postMessage(payload, window.location.origin);
    }
  } catch (_) {
    /* a host that cannot be reached is not a viewer failure */
  }
}

let renderer;
let scene;
let camera;
try {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: false, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  scene = new THREE.Scene();
  camera = new THREE.PerspectiveCamera(55, 1, 0.01, 1000);
  camera.position.set(0, 0, 3);
  scene.add(new SparkRenderer({ renderer }));
} catch (error) {
  renderer = undefined;
  status.textContent = "This device cannot show the spatial archive (WebGL is unavailable).";
  post(`error:webgl:${String(error)}`);
}

let mesh;
let loading = false;
let inView = true;
let rafId = 0;
let yaw = 0;
let pitch = 0;
let distance = 3;
let dragging = false;
let lastX = 0;
let lastY = 0;

function resize() {
  if (!renderer) return;
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  renderer.setSize(width, height, false);
  camera.aspect = width / Math.max(height, 1);
  camera.updateProjectionMatrix();
}

// The render loop runs only while it has something to show: a piece is loaded
// or loading, the canvas is actually on screen, and the tab is visible. A
// failed viewer, a scrolled-away page and a background tab render nothing.
function shouldRun() {
  return Boolean(renderer) && (Boolean(mesh) || loading) && inView && document.visibilityState !== "hidden";
}

function wake() {
  if (rafId === 0 && shouldRun()) rafId = requestAnimationFrame(frame);
}

function frame() {
  rafId = 0;
  if (!shouldRun()) return;
  resize();
  camera.position.set(
    Math.sin(yaw) * Math.cos(pitch) * distance,
    Math.sin(pitch) * distance,
    Math.cos(yaw) * Math.cos(pitch) * distance,
  );
  camera.lookAt(0, 0, 0);
  renderer.render(scene, camera);
  wake();
}

document.addEventListener("visibilitychange", wake);
if (typeof IntersectionObserver === "function") {
  new IntersectionObserver((entries) => {
    const latest = entries[entries.length - 1];
    inView = latest ? latest.isIntersecting : true;
    wake();
  }).observe(canvas);
}

canvas.addEventListener("pointerdown", (event) => {
  dragging = true;
  lastX = event.clientX;
  lastY = event.clientY;
  canvas.setPointerCapture(event.pointerId);
});
canvas.addEventListener("pointermove", (event) => {
  if (!dragging) return;
  yaw -= (event.clientX - lastX) * 0.006;
  pitch = Math.max(-1.35, Math.min(1.35, pitch + (event.clientY - lastY) * 0.006));
  lastX = event.clientX;
  lastY = event.clientY;
});
canvas.addEventListener("pointerup", () => { dragging = false; });
canvas.addEventListener("pointercancel", () => { dragging = false; });
canvas.tabIndex = 0;
canvas.addEventListener("keydown", (event) => {
  const step = 0.12;
  if (event.key === "ArrowLeft") yaw += step;
  else if (event.key === "ArrowRight") yaw -= step;
  else if (event.key === "ArrowUp") pitch = Math.min(1.35, pitch + step);
  else if (event.key === "ArrowDown") pitch = Math.max(-1.35, pitch - step);
  else if (event.key === "+" || event.key === "=") distance = Math.max(0.4, distance * 0.9);
  else if (event.key === "-") distance = Math.min(15, distance / 0.9);
  else if (event.key === "Escape") {
    // Lets an embedding page take the viewer out of its interactive state.
    canvas.blur();
    post("escape");
    return;
  } else return;
  event.preventDefault();
});
// A wheel gesture zooms only once the visitor has focused the viewer (click or
// Tab) or pinches (ctrl+wheel); otherwise it is left alone. (An embedding web
// page keeps this iframe inert until the visitor activates it, so page scroll
// never has to cross it; see spatial_viewer_web.dart.)
canvas.addEventListener("wheel", (event) => {
  if (!event.ctrlKey && document.activeElement !== canvas) return;
  event.preventDefault();
  distance = Math.max(0.4, Math.min(15, distance * Math.exp(event.deltaY * 0.001)));
}, { passive: false });

window.resetSpatialView = () => {
  yaw = 0;
  pitch = 0;
  distance = 3;
};

const FILE_TYPES = new Set(["ply", "spz", "splat", "ksplat", "pcsogs", "pcsogszip", "rad"]);

// Hosts may name the viewer for assistive technology in the visitor's language.
function applyLabel(label) {
  if (typeof label === "string" && label.length > 0 && label.length <= 200) {
    canvas.setAttribute("aria-label", label);
  }
}

/**
 * Applies the manifest `transform` so a piece opens upright and centred.
 * `matrix` is 16 numbers in column-major order (three.js Matrix4.fromArray),
 * the form the kubus Node writes. `position` / `rotation` (quaternion xyzw or
 * Euler radians xyz) / `scale` (number or [x, y, z]) are the fallback shape.
 */
function applyManifestTransform(target, transform) {
  if (!transform || typeof transform !== "object") return false;
  const finite = (value) => typeof value === "number" && Number.isFinite(value);
  const { matrix } = transform;
  if (
    Array.isArray(matrix) &&
    matrix.length === 16 &&
    matrix.every(finite) &&
    (transform.matrixOrder === undefined || transform.matrixOrder === "column-major")
  ) {
    target.matrix.fromArray(matrix);
    target.matrix.decompose(target.position, target.quaternion, target.scale);
    const { x, y, z } = target.scale;
    if (![x, y, z].every((value) => Number.isFinite(value) && value > 0)) {
      target.position.set(0, 0, 0);
      target.quaternion.identity();
      target.scale.set(1, 1, 1);
      return false;
    }
    return true;
  }
  let applied = false;
  const { position, rotation, scale } = transform;
  if (Array.isArray(position) && position.length === 3 && position.every(finite)) {
    target.position.fromArray(position);
    applied = true;
  }
  if (Array.isArray(rotation) && rotation.every(finite)) {
    if (rotation.length === 4) {
      target.quaternion.fromArray(rotation).normalize();
      applied = true;
    } else if (rotation.length === 3) {
      target.rotation.set(rotation[0], rotation[1], rotation[2]);
      applied = true;
    }
  }
  if (finite(scale) && scale > 0) {
    target.scale.setScalar(scale);
    applied = true;
  } else if (Array.isArray(scale) && scale.length === 3 && scale.every((value) => finite(value) && value > 0)) {
    target.scale.fromArray(scale);
    applied = true;
  }
  return applied;
}

async function loadOne(url, transform, fileType) {
  if (mesh) {
    scene.remove(mesh);
    mesh.dispose?.();
    mesh = undefined;
  }
  loading = true;
  wake();
  const options = { url };
  if (typeof fileType === "string" && FILE_TYPES.has(fileType)) options.fileType = fileType;
  const next = new SplatMesh(options);
  applyManifestTransform(next, transform);
  scene.add(next);
  try {
    await next.initialized;
  } catch (error) {
    scene.remove(next);
    next.dispose?.();
    throw error;
  }
  mesh = next;
}

// Tries each route in order; the first that yields a splat wins.
async function loadFirst(urls, transform, fileType) {
  if (!renderer) return;
  status.textContent = "Loading spatial archive…";
  status.hidden = false;
  let lastError;
  for (const url of urls) {
    try {
      await loadOne(url, transform, fileType);
      loading = false;
      status.hidden = true;
      wake();
      post("ready");
      return;
    } catch (error) {
      lastError = error;
    }
  }
  loading = false;
  status.textContent = "This spatial archive could not be loaded.";
  post(`error:${String(lastError)}`);
}

// Native hosts (the app's WebView) call this directly, with a URL they chose
// themselves, so it does not apply the web host's URL allow-list below. It is
// reachable only by script already running in this page, which is the app's own
// bundle; the web host never uses it and goes through the checked message path.
window.loadSpatial = (url, transform, fileType) => loadFirst([url], transform, fileType);

function allowedUrl(value) {
  if (typeof value !== "string") return undefined;
  try {
    const parsed = new URL(value, window.location.href);
    const allowed =
      parsed.protocol === "https:" ||
      parsed.protocol === "blob:" ||
      parsed.origin === window.location.origin;
    return allowed ? parsed.href : undefined;
  } catch (_) {
    return undefined;
  }
}

// Web host protocol: same-origin parent only; https / same-origin / blob URLs only.
window.addEventListener("message", (event) => {
  if (event.source !== window.parent || event.origin !== window.location.origin) return;
  const command = event.data && event.data.kubusSpatialViewerCommand;
  if (!command || typeof command !== "object") return;
  if (command.type === "reset") {
    window.resetSpatialView();
  } else if (command.type === "activate") {
    canvas.focus({ preventScroll: true });
  } else if (command.type === "deactivate") {
    canvas.blur();
  } else if (command.type === "load") {
    const candidates = Array.isArray(command.urls) ? command.urls : [command.url];
    const urls = candidates.map(allowedUrl).filter(Boolean).slice(0, 6);
    if (urls.length === 0) {
      post("error:url-not-allowed");
      return;
    }
    applyLabel(command.label);
    void loadFirst(urls, command.transform, command.fileType);
  }
});

// Read-only diagnostics for the browser smoke test.
window.__spatialDebug = () => ({
  hasMesh: Boolean(mesh),
  running: rafId !== 0,
  inView,
  matrix: mesh ? mesh.matrix.toArray() : null,
  yaw,
  pitch,
  distance,
});

post("viewer-ready");
