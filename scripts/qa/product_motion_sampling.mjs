// Sampling requirements for the real-pixel PRODUCT motion gate.
export const MIN_SETTLED_FRAMES = 14;
export const FLOAT_PERIOD_MS = 2200;
const SAMPLE_BUDGET_MARGIN_MS = 3000;
// Largest allowed hole in the float phases sampled so far (a quarter period).
export const MAX_PHASE_GAP_FRACTION = 0.25;
const PHASE_STEP_MS = 50;

export function getSamplingDeadlineMs(
  captureMs,
  {
    holdMs,
    settleMs,
    minFrames = MIN_SETTLED_FRAMES,
    floatPeriodMs = FLOAT_PERIOD_MS,
    maxHoldMs,
    phaseWaitMs = 0,
  },
) {
  const captureWindowMs =
    Math.max(minFrames * (captureMs + phaseWaitMs), floatPeriodMs) + captureMs + settleMs;
  return Math.min(maxHoldMs, Math.max(holdMs + 1000, captureWindowMs + SAMPLE_BUDGET_MARGIN_MS));
}

export function getSettledSamplingCoverage(
  frames,
  { settleMs, minFrames = MIN_SETTLED_FRAMES, floatPeriodMs = FLOAT_PERIOD_MS },
) {
  const settled = frames.filter((frame) => frame.t >= settleMs);
  const spanMs = settled.length > 1 ? settled.at(-1).t - settled[0].t : 0;
  const maxPhaseGapMs = getMaxPhaseGapMs(settled.map((frame) => frame.t), floatPeriodMs);
  return {
    count: settled.length,
    spanMs,
    maxPhaseGapMs,
    complete:
      settled.length >= minFrames &&
      spanMs >= floatPeriodMs &&
      maxPhaseGapMs <= floatPeriodMs * MAX_PHASE_GAP_FRACTION,
  };
}

const phaseOf = (t, periodMs) => ((t % periodMs) + periodMs) % periodMs;

// Largest circular gap between the float phases the samples landed on. A screenshot
// loop whose interval is a whole number of periods (Firefox paints take ~4.4 s,
// exactly two 2200 ms periods) sees one phase every time and reports no motion.
export function getMaxPhaseGapMs(times, periodMs = FLOAT_PERIOD_MS) {
  if (!times.length) return periodMs;
  const phases = times.map((t) => phaseOf(t, periodMs)).sort((a, b) => a - b);
  let gap = phases[0] + periodMs - phases.at(-1);
  for (let i = 1; i < phases.length; i += 1) gap = Math.max(gap, phases[i] - phases[i - 1]);
  return gap;
}

const circularDistance = (a, b, periodMs) => {
  const d = Math.abs(a - b) % periodMs;
  return Math.min(d, periodMs - d);
};

// How long to wait before the next capture so that its float phase falls in the
// largest uncovered stretch. Returns 0 whenever the natural cadence already lands
// well away from every sampled phase, so fast browsers pay nothing.
export function getNextSampleDelayMs(
  frames,
  { settleMs, nowMs, expectedCaptureMs, floatPeriodMs = FLOAT_PERIOD_MS },
) {
  const phases = frames.filter((frame) => frame.t >= settleMs).map((frame) => frame.t);
  if (!phases.length) return 0;
  const score = (delayMs) => {
    const t = nowMs + delayMs + expectedCaptureMs / 2;
    if (t < settleMs) return Infinity;
    const phase = phaseOf(t, floatPeriodMs);
    return Math.min(...phases.map((p) => circularDistance(phase, phaseOf(p, floatPeriodMs), floatPeriodMs)));
  };
  const candidates = [];
  for (let d = 0; d < floatPeriodMs; d += PHASE_STEP_MS) candidates.push([d, score(d)]);
  const naturalScore = score(0);
  const best = Math.max(...candidates.map(([, s]) => s));
  if (!Number.isFinite(best)) return 0;
  // Keep the natural cadence when it is already at least half as far from the
  // existing phases as the best available target. Otherwise choose the true
  // maximum-distance candidate, which bisects the largest uncovered phase gap.
  // Returning the first merely acceptable candidate can repeatedly place
  // samples off-center and leave a gap just beyond the contract limit.
  if (naturalScore >= best * 0.5) return 0;
  return candidates.reduce((bestCandidate, candidate) =>
    candidate[1] > bestCandidate[1] ? candidate : bestCandidate,
  )[0];
}
