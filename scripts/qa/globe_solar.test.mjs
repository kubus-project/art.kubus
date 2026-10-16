import test from 'node:test';
import assert from 'node:assert/strict';
import { getSubsolarPoint, sunDirectionInView } from '../../web/kubus_globe_sun.mjs';
import { nightRegionGeometry, limbRadius } from '../../web/kubus_globe_geometry.mjs';

test('real sun crosses the equinox and solstice without theme inputs', () => {
  assert.ok(Math.abs(getSubsolarPoint(new Date('2026-03-20T12:00:00Z')).lat) < 0.5);
  assert.ok(getSubsolarPoint(new Date('2026-06-21T12:00:00Z')).lat > 23);
  const a = getSubsolarPoint(new Date('2026-10-15T12:00:00Z'));
  const b = getSubsolarPoint(new Date('2026-10-15T12:00:01Z'));
  assert.ok(Math.abs(a.lng-b.lng+360)%360 < 0.005);
});

test('polar and dateline views retain finite bounded night geometry', () => {
  const cam = { D: 3, k: 600 };
  for (const lat of [-90,-89,0,89,90]) for (const lng of [-180,0,180]) {
    const direction = sunDirectionInView(getSubsolarPoint(new Date('2026-12-21T12:00:00Z')),lng,lat);
    const {nightRegion} = nightRegionGeometry(direction, cam);
    for (const [x,y] of nightRegion) {
      assert.ok(Number.isFinite(x) && Number.isFinite(y));
      assert.ok(Math.hypot(x,y) <= limbRadius(cam)+1e-6);
    }
  }
});
