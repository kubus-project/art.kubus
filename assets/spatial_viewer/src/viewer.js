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

window.loadSpatial = async (url) => {
  status.textContent = "Loading spatial archive…";
  status.hidden = false;
  try {
    if (mesh) scene.remove(mesh);
    mesh = new SplatMesh({ url });
    scene.add(mesh);
    await mesh.initialized;
    status.hidden = true;
    window.SpatialViewer?.postMessage("ready");
  } catch (error) {
    status.textContent = "This spatial archive could not be loaded.";
    window.SpatialViewer?.postMessage(`error:${String(error)}`);
  }
};

frame();
window.SpatialViewer?.postMessage("viewer-ready");
