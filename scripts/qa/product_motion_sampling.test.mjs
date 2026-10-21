import test from 'node:test';
import assert from 'node:assert/strict';

import {
  FLOAT_PERIOD_MS,
  MIN_SETTLED_FRAMES,
  getMaxPhaseGapMs,
  getNextSampleDelayMs,
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

test('CI-length captures can collect required painted frames without relaxing coverage', () => {
  const options = { holdMs: 3200, settleMs: 600, maxHoldMs: 90000 };
  const captureDurations = [4900, 4800, 5100, 4700, 5000];
  let elapsed = 0;
  const frames = Array.from({ length: MIN_SETTLED_FRAMES }, (_, index) => {
    const duration = captureDurations[index % captureDurations.length];
    const t = elapsed + duration / 2;
    elapsed += duration;
    return { t };
  });
  const deadline = getSamplingDeadlineMs(Math.max(...captureDurations), options);
  assert.ok(elapsed > 60000, 'the previous cap stopped before sufficient captures');
  assert.ok(elapsed <= deadline && deadline <= options.maxHoldMs);
  assert.equal(getSettledSamplingCoverage(frames, options).complete, true);
  assert.equal(getSettledSamplingCoverage(frames.slice(0, -1), options).complete, false);
  assert.equal(getSamplingDeadlineMs(20000, options), options.maxHoldMs);
});

test('samples whose interval is a whole number of float periods are rejected as aliased', () => {
  // Firefox CI paints take ~4.4 s: exactly two periods, so every sample sees one phase.
  const aliased = Array.from({ length: 30 }, (_, i) => ({ t: 700 + i * 2 * FLOAT_PERIOD_MS }));
  const result = getSettledSamplingCoverage(aliased, { settleMs: 600 });

  assert.ok(result.count >= MIN_SETTLED_FRAMES);
  assert.ok(result.spanMs >= FLOAT_PERIOD_MS);
  assert.equal(result.maxPhaseGapMs, FLOAT_PERIOD_MS);
  assert.equal(result.complete, false);
  assert.equal(getMaxPhaseGapMs([]), FLOAT_PERIOD_MS);
});

test('phase-targeted waits cover the float cycle for every steady capture cadence', () => {
  const options = { settleMs: 600 };
  for (let captureMs = 300; captureMs <= 5400; captureMs += 50) {
    const frames = [];
    let now = 0;
    while (!getSettledSamplingCoverage(frames, options).complete && frames.length < 40) {
      const wait = frames.length
        ? getNextSampleDelayMs(frames, { ...options, nowMs: now, expectedCaptureMs: captureMs })
        : 0;
      now += wait + captureMs;
      frames.push({ t: now - captureMs / 2 });
    }
    const coverage = getSettledSamplingCoverage(frames, options);
    assert.equal(coverage.complete, true, `capture ${captureMs}ms never covered the cycle`);
    assert.ok(coverage.count <= 30, `capture ${captureMs}ms needed ${coverage.count} samples`);
  }
});

test('phase targets cover the float cycle with jittered Firefox-length captures', () => {
  const options = { settleMs: 600 };
  const captureDurations = [3400, 3700, 3500, 3650, 3450, 3700, 3550, 3400];
  const frames = [];
  let now = 0;
  let previousCaptureMs = 0;
  while (!getSettledSamplingCoverage(frames, options).complete && frames.length < 40) {
    const wait = frames.length
      ? getNextSampleDelayMs(frames, {
          ...options,
          nowMs: now,
          expectedCaptureMs: previousCaptureMs,
        })
      : 0;
    const captureMs = captureDurations[frames.length % captureDurations.length];
    const captureStarted = now + wait;
    frames.push({ t: captureStarted + captureMs / 2 });
    now = captureStarted + captureMs;
    previousCaptureMs = captureMs;
  }

  const coverage = getSettledSamplingCoverage(frames, options);
  assert.equal(coverage.complete, true);
  assert.ok(coverage.maxPhaseGapMs < FLOAT_PERIOD_MS * 0.25 - 25);
  assert.ok(frames.length <= 30, `jittered captures needed ${frames.length} samples`);
});

test('a cadence that already lands on fresh phases is never delayed', () => {
  const frames = framesAt(700, 1500, 2300);
  assert.equal(
    getNextSampleDelayMs(frames, { settleMs: 600, nowMs: 2400, expectedCaptureMs: 600 }),
    0,
  );
});

test('the sampling deadline budgets phase waits without changing the capture-only budget', () => {
  const options = { holdMs: 3200, settleMs: 600, maxHoldMs: 90000 };
  assert.equal(getSamplingDeadlineMs(2500, options), getSamplingDeadlineMs(2500, { ...options, phaseWaitMs: 0 }));
  assert.ok(getSamplingDeadlineMs(2500, { ...options, phaseWaitMs: 550 }) > getSamplingDeadlineMs(2500, options));
});
