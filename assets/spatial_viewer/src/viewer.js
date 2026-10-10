import * as THREE from "three";
import { SparkRenderer, SplatMesh } from "@sparkjsdev/spark";

const canvas = document.querySelector("canvas");
const status = document.querySelector("#status");
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, alpha: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(55, 1, 0.01, 1000);
camera.position.set(0, 0, 3);
const spark = new SparkRenderer({ renderer });
scene.add(spark);

let mesh;
let yaw = 0;
let pitch = 0;
let distance = 3;
let dragging = false;
let lastX = 0;
let lastY = 0;

function resize() {
  const width = canvas.clientWidth;
  const height = canvas.clientHeight;
  renderer.setSize(width, height, false);
  camera.aspect = width / Math.max(height, 1);
  camera.updateProjectionMatrix();
}

function frame() {
  resize();
  camera.position.set(
    Math.sin(yaw) * Math.cos(pitch) * distance,
    Math.sin(pitch) * distance,
    Math.cos(yaw) * Math.cos(pitch) * distance,
  );
  camera.lookAt(0, 0, 0);
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
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
canvas.addEventListener("wheel", (event) => {
  event.preventDefault();
  distance = Math.max(0.4, Math.min(15, distance * Math.exp(event.deltaY * 0.001)));
}, { passive: false });

window.resetSpatialView = () => {
  yaw = 0;
  pitch = 0;
  distance = 3;
};

// One load at a time. Each load takes a generation number; anything that finishes
// after a newer load (or an unload) started discards its result instead of
// putting a stale scene on screen.
let generation = 0;
const state = { stage: "idle", previewSplats: 0, runtimeSplats: 0, warnings: [] };

function discard(object) {
  if (!object) return;
  scene.remove(object);
  object.dispose?.();
}

function tell(message) {
  window.SpatialViewer?.postMessage(message);
}

function nextFrame() {
  return new Promise((resolve) => requestAnimationFrame(() => resolve()));
}

async function untilDrawn(mesh, isStale, timeoutMs) {
  // A paged tree is initialised as soon as its header is read; it has something to
  // draw only once the first page has been fetched, decoded and indexed.
  const deadline = performance.now() + timeoutMs;
  while (!isStale() && performance.now() < deadline) {
    if ((mesh.paged?.numSplats ?? 0) > 0) {
      await nextFrame();
      await nextFrame();
      return true;
    }
    await nextFrame();
  }
  return false;
}

window.loadSpatial = async (url) => {
  generation += 1;
  state.stage = "loading";
  status.textContent = "Loading spatial archive…";
  status.hidden = false;
  try {
    if (mesh) scene.remove(mesh);
    mesh = new SplatMesh({ url });
    scene.add(mesh);
    await mesh.initialized;
    state.stage = "single";
    status.hidden = true;
    window.SpatialViewer?.postMessage("ready");
  } catch (error) {
    state.stage = "failed";
    status.textContent = "This spatial archive could not be loaded.";
    window.SpatialViewer?.postMessage(`error:${String(error)}`);
  }
};

// Progressive load: the small preview is drawn first, then the paged runtime tree
// replaces it as soon as it can draw. The reconstruction archive is never loaded
// here - it is for download, and `loadSpatial(url)` still opens one on request.
//
// Returns { ok, stage, ... }. A runtime that fails keeps the preview on screen and
// is reported as a warning; only when nothing can be shown is it a failure.
window.loadSpatialProgressive = async ({ preview, runtime, runtimeTimeoutMs = 30000 } = {}) => {
  generation += 1;
  const mine = generation;
  const isStale = () => mine !== generation;
  discard(mesh);
  mesh = undefined;
  state.stage = "loading";
  state.previewSplats = 0;
  state.runtimeSplats = 0;
  state.warnings = [];
  status.textContent = "Loading spatial archive…";
  status.hidden = false;

  let previewMesh;
  if (preview) {
    try {
      previewMesh = new SplatMesh({ url: preview });
      scene.add(previewMesh);
      await previewMesh.initialized;
      if (isStale()) {
        discard(previewMesh);
        return { ok: false, stale: true };
      }
      mesh = previewMesh;
      state.stage = "preview";
      state.previewSplats = previewMesh.numSplats ?? 0;
      status.hidden = true;
      tell("ready");
      tell("stage:preview");
    } catch (error) {
      discard(previewMesh);
      previewMesh = undefined;
      state.warnings.push(`preview:${String(error)}`);
      tell(`warning:preview:${String(error)}`);
    }
  }

  if (runtime) {
    let runtimeMesh;
    try {
      runtimeMesh = new SplatMesh({ url: runtime, paged: true });
      scene.add(runtimeMesh);
      await runtimeMesh.initialized;
      const drawn = await untilDrawn(runtimeMesh, isStale, runtimeTimeoutMs);
      if (isStale()) {
        discard(runtimeMesh);
        return { ok: false, stale: true };
      }
      if (!drawn) throw new Error("the runtime tree drew nothing in time");
      discard(previewMesh);
      mesh = runtimeMesh;
      state.stage = "runtime";
      state.runtimeSplats = runtimeMesh.paged?.numSplats ?? 0;
      status.hidden = true;
      tell("ready");
      tell("stage:runtime");
    } catch (error) {
      discard(runtimeMesh);
      state.warnings.push(`runtime:${String(error)}`);
      tell(`warning:runtime:${String(error)}`);
    }
  }

  if (isStale()) return { ok: false, stale: true };
  if (!mesh) {
    state.stage = "failed";
    status.textContent = "This spatial archive could not be loaded.";
    status.hidden = false;
    tell(`error:${state.warnings.join("; ") || "nothing to load"}`);
    return { ok: false, stage: state.stage, warnings: [...state.warnings] };
  }
  return { ok: true, stage: state.stage, warnings: [...state.warnings] };
};

// Releases the scene and every GPU resource behind it; a pending load is abandoned.
window.unloadSpatial = () => {
  generation += 1;
  discard(mesh);
  mesh = undefined;
  state.stage = "idle";
};

window.spatialViewerState = () => ({ ...state, warnings: [...state.warnings] });

frame();
window.SpatialViewer?.postMessage("viewer-ready");
