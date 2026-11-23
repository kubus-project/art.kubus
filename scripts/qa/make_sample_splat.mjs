// Generates the small synthetic splat used by the spatial viewer smoke test.
// Not a real capture and not any artist's work: a procedural "flower" lying on
// its side (stem along +X, head at +X). A manifest transform that rotates it a
// quarter turn about Z stands it upright, which is what the smoke test checks.
//
// Usage: node scripts/qa/make_sample_splat.mjs <out.splat>
// Format: antimatter15 .splat, 32 bytes per splat:
//   3 x float32 position, 3 x float32 scale, 4 x uint8 RGBA, 4 x uint8 quaternion (w, x, y, z).
import fs from 'node:fs';

const out = process.argv[2];
if (!out) throw new Error('usage: make_sample_splat.mjs <out.splat>');

// Deterministic pseudo-random so the fixture is reproducible.
let seed = 0x6b756275;
const rand = () => {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return seed / 0x100000000;
};

const splats = [];
const push = (x, y, z, size, r, g, b) => splats.push({ x, y, z, size, r, g, b });

// Stem: green, from x = -1 to x = 0.55.
for (let i = 0; i < 1400; i += 1) {
  const x = -1 + rand() * 1.55;
  const a = rand() * Math.PI * 2;
  const radius = 0.035 * Math.sqrt(rand());
  push(x, Math.cos(a) * radius, Math.sin(a) * radius, 0.022, 40, 170 + rand() * 40, 60);
}
// Head: red petals in a disc around x = 0.75, yellow centre.
for (let i = 0; i < 3600; i += 1) {
  const a = rand() * Math.PI * 2;
  const radius = 0.1 + 0.42 * Math.sqrt(rand());
  const ripple = 1 + 0.18 * Math.cos(a * 6);
  push(
    0.75 + (rand() - 0.5) * 0.05,
    Math.cos(a) * radius * ripple,
    Math.sin(a) * radius * ripple,
    0.03,
    215 + rand() * 30,
    30 + rand() * 30,
    50 + rand() * 30,
  );
}
for (let i = 0; i < 500; i += 1) {
  const a = rand() * Math.PI * 2;
  const radius = 0.11 * Math.sqrt(rand());
  push(0.78, Math.cos(a) * radius, Math.sin(a) * radius, 0.03, 245, 205 + rand() * 30, 40);
}

const buffer = Buffer.alloc(splats.length * 32);
splats.forEach((s, i) => {
  const o = i * 32;
  buffer.writeFloatLE(s.x, o);
  buffer.writeFloatLE(s.y, o + 4);
  buffer.writeFloatLE(s.z, o + 8);
  buffer.writeFloatLE(s.size, o + 12);
  buffer.writeFloatLE(s.size, o + 16);
  buffer.writeFloatLE(s.size, o + 20);
  buffer[o + 24] = Math.round(s.r);
  buffer[o + 25] = Math.round(s.g);
  buffer[o + 26] = Math.round(s.b);
  buffer[o + 27] = 255;
  buffer[o + 28] = 255; // w
  buffer[o + 29] = 128; // x
  buffer[o + 30] = 128; // y
  buffer[o + 31] = 128; // z
});
fs.writeFileSync(out, buffer);
console.log(`${splats.length} splats, ${buffer.length} bytes -> ${out}`);
