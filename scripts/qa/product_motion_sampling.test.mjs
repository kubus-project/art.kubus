import test from 'node:test';
import assert from 'node:assert/strict';

import {
  FLOAT_PERIOD_MS,
  MIN_SETTLED_FRAMES,
  getSettledSamplingCoverage,
  getSamplingDeadlineMs,
} from './product_motion_sampling.mjs';

const framesAt = (...times) => times.map((t) => ({ t }));

test('normal motion needs settled pixel samples spanning a full float period', () => {
  const settled = Array.from({ length: MIN_SETTLED_FRAMES }, (_, i) => ({ t: 700 + i * 200 }));
  const result = getSettledSamplingCoverage(
    [...framesAt(100), ...settled],
    { settleMs: 600 },
  );

  assert.equal(result.count, MIN_SETTLED_FRAMES);
  assert.equal(result.spanMs, 2600);
  assert.ok(result.spanMs >= FLOAT_PERIOD_MS);
  assert.equal(result.complete, true);
});

test('normal motion rejects enough samples when their settled time span is short', () => {
  const settled = Array.from({ length: MIN_SETTLED_FRAMES }, (_, i) => ({ t: 700 + i * 20 }));
  const result = getSettledSamplingCoverage(
    settled,
    { settleMs: 600 },
  );

  assert.equal(result.count, MIN_SETTLED_FRAMES);
  assert.equal(result.complete, false);
});

test('normal motion rejects a full period with too few painted samples', () => {
  const settled = Array.from({ length: MIN_SETTLED_FRAMES - 1 }, (_, i) => ({ t: 700 + i * 200 }));
  const result = getSettledSamplingCoverage(settled, { settleMs: 600 });

  assert.ok(result.spanMs >= FLOAT_PERIOD_MS);
  assert.equal(result.complete, false);
});

test('reduced motion still requires enough settled samples over the full observation span', () => {
  const reducedFrames = [
    ...framesAt(100),
    ...Array.from({ length: MIN_SETTLED_FRAMES }, (_, i) => ({ t: 700 + i * 200 })),
  ];
  const result = getSettledSamplingCoverage(reducedFrames, { settleMs: 600 });

  assert.equal(result.count, MIN_SETTLED_FRAMES);
  assert.ok(result.spanMs >= FLOAT_PERIOD_MS);
  assert.equal(result.complete, true);
});

test('sampling deadline expands for slow captures and stays within its hard cap', () => {
  const options = { holdMs: 3200, settleMs: 600, maxHoldMs: 60000 };
  const normal = getSamplingDeadlineMs(100, options);
  const slow = getSamplingDeadlineMs(2500, options);

  assert.ok(normal >= options.holdMs);
  assert.ok(slow > normal);
  assert.equal(slow, 41100);
  assert.equal(getSamplingDeadlineMs(3000, options), 48600);
  assert.equal(getSamplingDeadlineMs(5000, options), options.maxHoldMs);
});
