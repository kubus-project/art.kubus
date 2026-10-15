// Globe is a web-only renderer capability. Keep its decorative pass local to
// that surface: no Flutter tree ticks, map source writes, or native globe fork.
import { getSubsolarPoint, sunDirectionInView } from './kubus_globe_sun.mjs';
import { destinationPoint, solveGlobeCamera, fitGlobeCamera, limbAngleDeg, limbRadius,
  screenDistanceAt, nightRegionGeometry } from './kubus_globe_geometry.mjs';

export function globeView(map) {
  const center = map.getCenter();
  const ring = (angle) => [0, 90, 180, 270].map((bearing) => {
    const p = destinationPoint(center.lat, center.lng, bearing, angle);
    return map.project([p.lng, p.lat]);
  });
  const rings = [ring(25), ring(55)];
  const points = rings.flat();
  if (!points.every((p) => Number.isFinite(p.x) && Number.isFinite(p.y))) return null;
  const x = points.reduce((sum, p) => sum + p.x, 0) / points.length;
  const y = points.reduce((sum, p) => sum + p.y, 0) / points.length;
  const distance = (p) => Math.hypot(p.x - x, p.y - y);
  const distances = rings.map((pts) => pts.reduce((sum, p) => sum + distance(p), 0) / pts.length);
  let cam = solveGlobeCamera(distances[0], 25, distances[1], 55);
  if (!cam) return null;
  // Reject flattening/pitch and a bad limb fit instead of drawing a false edge.
  const predicts = () => [50, limbAngleDeg(cam)].every((angle) => ring(angle).every((p) =>
    Math.abs(distance(p) - screenDistanceAt(angle, cam)) < 1));
  if (!predicts()) {
    cam = fitGlobeCamera([15,25,35,45,55,65].flatMap((angle) =>
      ring(angle).map((p) => ({ thetaDeg: angle, distance: distance(p) }))));
    if (!cam || !predicts()) return null;
  }
  return { cam, x, y };
}

export function attachGlobeAtmosphere(map) {
  const host = map.getContainer();
  const canvas = document.createElement('canvas');
  canvas.className = 'kubus-globe-atmosphere';
  canvas.setAttribute('aria-hidden', 'true');
  Object.assign(canvas.style, { position: 'absolute', inset: '0', pointerEvents: 'none' });
  host.appendChild(canvas);
  const ctx = canvas.getContext('2d');
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  let visible = false, disposed = false, timer = null, signature = '';
  const stop = () => { clearTimeout(timer); timer = null; };
  const draw = () => {
    if (disposed || !visible || document.hidden || globalThis.kubusMapPresentationActive === false || !ctx) return;
    const width = host.clientWidth, height = host.clientHeight;
    const zoom = map.getZoom();
    const center = map.getCenter();
    const now = new Date();
    const sun = getSubsolarPoint(now);
    canvas.dataset.subsolar = `${sun.lat.toFixed(6)},${sun.lng.toFixed(6)}`;
    const next = [width, height, zoom, center.lat, center.lng, map.getBearing(),
      map.getPitch(), Math.floor(now.getTime() / 1000)].join(':');
    if (next === signature) return;
    signature = next;
    // DPR is bounded: the field has a soft astronomical boundary, no fine text.
    const ratio = Math.min(devicePixelRatio || 1, 1.5);
    if (canvas.width !== Math.round(width * ratio) || canvas.height !== Math.round(height * ratio)) {
      canvas.width = Math.round(width * ratio); canvas.height = Math.round(height * ratio);
      canvas.style.width = `${width}px`; canvas.style.height = `${height}px`;
    }
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    ctx.clearRect(0, 0, width, height);
    canvas.dataset.active = 'false';
    if (map.getProjection?.()?.type !== 'globe' || zoom >= 4.6 || map.getPitch() > 0.1) return;
    const view = globeView(map);
    if (!view) return;
    const direction = sunDirectionInView(sun, center.lng, center.lat);
    const angle = map.getBearing() * Math.PI / 180;
    const rotated = { x: direction.x * Math.cos(angle) - direction.y * Math.sin(angle),
      y: direction.x * Math.sin(angle) + direction.y * Math.cos(angle), z: direction.z };
    const radius = limbRadius(view.cam);
    canvas.dataset.active = 'true';
    canvas.dataset.radius = String(radius);
    const blur = Math.max(1.5, Math.min(8, radius * 0.015));
    const region = nightRegionGeometry(rotated, view.cam, 96, blur * 4).nightRegion;
    if (!region.length) return;
    ctx.save();
    ctx.beginPath(); ctx.arc(view.x, view.y, Math.max(0, radius - 0.25), 0, 2 * Math.PI); ctx.clip();
    ctx.filter = `blur(${blur}px)`;
    ctx.globalAlpha = 0.36 * Math.min(1, (4.6 - zoom) / 1.4);
    ctx.fillStyle = '#000000';
    ctx.beginPath();
    region.forEach(([x, y], i) => i ? ctx.lineTo(view.x+x, view.y+y) : ctx.moveTo(view.x+x, view.y+y));
    ctx.closePath(); ctx.fill(); ctx.restore();
    canvas.dataset.subsolar = `${sun.lat.toFixed(6)},${sun.lng.toFixed(6)}`;
  };
  const schedule = () => {
    stop();
    draw();
    // Real time at a gentle cadence. Reduced motion retains the current solar
    // state and camera reprojection, without a repeating presentation clock.
    if (!disposed && visible && !document.hidden && globalThis.kubusMapPresentationActive !== false && !motion.matches && map.getZoom() < 4.6) {
      timer = setTimeout(schedule, 1000);
    }
  };
  const style = () => {
    signature = '';
    const layers = map.getStyle()?.layers || [];
    const background = layers.find((layer) => layer.type === 'background')?.paint?.['background-color'];
    const hex = typeof background === 'string' ? background.match(/^#([0-9a-f]{6})$/i)?.[1] : null;
    if (hex) {
      const rgb = [0,2,4].map((i) => parseInt(hex.slice(i, i+2),16));
      const ground = rgb.reduce((s,v) => s+v,0) < 384 ? '#000000' : '#ffffff';
      map.getCanvas().style.backgroundColor = ground;
      map.getCanvasContainer().style.backgroundColor = ground;
    }
    schedule();
  };
  const observer = new IntersectionObserver((entries) => {
    visible = entries.some((entry) => entry.isIntersecting);
    signature = ''; schedule();
  });
  // A jump from a local Mercator view starts MapLibre's projection blend after
  // the final camera event. Reduced motion has no solar timer to pick up that
  // settled projection, so retry once on idle when no valid field was fitted.
  const settled = () => {
    if (canvas.dataset.active !== 'true' && map.getZoom() < 4.6) {
      signature = ''; schedule();
    }
  };
  observer.observe(host);
  map.on('move', schedule); map.on('resize', style); map.on('style.load', style);
  map.on('idle', settled);
  document.addEventListener('visibilitychange', schedule); motion.addEventListener('change', schedule);
  window.addEventListener('kubus-map-presentation-change', schedule);
  map.once('remove', () => {
    disposed = true; stop(); observer.disconnect(); canvas.remove();
    document.removeEventListener('visibilitychange', schedule); motion.removeEventListener('change', schedule);
    window.removeEventListener('kubus-map-presentation-change', schedule);
    map.off('move', schedule); map.off('resize', style); map.off('style.load', style);
    map.off('idle', settled);
  });
  style();
}

export function installGlobeAtmosphere(runtime) {
  const OriginalMap = runtime.Map;
  runtime.Map = class KubusAtmosphereMap extends OriginalMap {
    constructor(options) {
      super(options);
      let attached = false;
      this.on('style.load', () => {
        if (!attached && this.getProjection?.()?.type === 'globe') {
          attached = true;
          attachGlobeAtmosphere(this);
        }
      });
    }
  };
}
