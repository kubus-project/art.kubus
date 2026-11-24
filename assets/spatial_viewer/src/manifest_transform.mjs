// Pure acceptance rules for a published manifest `transform`. No DOM, no three.js,
// so a Node test can import it. The Dart side (SpatialWebDelivery.transformFromManifest)
// applies the same rules before the transform is handed to the viewer; this is the
// second, independent check inside the page. Keep the two in step.
//
// A manifest is public data written by an artist's node. A transform that is
// non-affine, sheared, mirrored or absurdly large is not a placement; the piece then
// opens untransformed instead of vanishing or exploding.

export const MAX_POSITION = 1e6;
export const MIN_SCALE = 1e-6;
export const MAX_SCALE = 1e4;

const EPS = 1e-6;
const SHEAR = 1e-3;

const finite = (value) => typeof value === "number" && Number.isFinite(value);

export function acceptedPosition(position) {
  return (
    Array.isArray(position) &&
    position.length === 3 &&
    position.every((value) => finite(value) && Math.abs(value) <= MAX_POSITION)
  );
}

export function acceptedScale(scale) {
  const ok = (value) => finite(value) && value >= MIN_SCALE && value <= MAX_SCALE;
  if (Array.isArray(scale)) return scale.length === 3 && scale.every(ok);
  return ok(scale);
}

/**
 * A column-major 4x4 that is a proper affine rigid-plus-scale placement: bottom row
 * (0, 0, 0, 1), bounded translation, axis lengths inside the scale bounds, mutually
 * perpendicular axes (no shear) and a right-handed basis (no mirror).
 */
export function acceptedMatrix(matrix) {
  if (!Array.isArray(matrix) || matrix.length !== 16 || !matrix.every(finite)) return false;
  if (Math.abs(matrix[3]) > EPS || Math.abs(matrix[7]) > EPS || Math.abs(matrix[11]) > EPS) return false;
  if (Math.abs(matrix[15] - 1) > EPS) return false;
  if ([12, 13, 14].some((i) => Math.abs(matrix[i]) > MAX_POSITION)) return false;
  const axes = [matrix.slice(0, 3), matrix.slice(4, 7), matrix.slice(8, 11)];
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const lengths = axes.map((axis) => Math.sqrt(dot(axis, axis)));
  if (!lengths.every((length) => length >= MIN_SCALE && length <= MAX_SCALE)) return false;
  for (const [i, j] of [[0, 1], [0, 2], [1, 2]]) {
    if (Math.abs(dot(axes[i], axes[j])) > SHEAR * lengths[i] * lengths[j]) return false;
  }
  const [a, b, c] = axes;
  const cross = [b[1] * c[2] - b[2] * c[1], b[2] * c[0] - b[0] * c[2], b[0] * c[1] - b[1] * c[0]];
  return dot(a, cross) > 0;
}
