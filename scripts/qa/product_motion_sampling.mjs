// Sampling requirements for the real-pixel PRODUCT motion gate.
export const MIN_SETTLED_FRAMES = 14;
export const FLOAT_PERIOD_MS = 2200;
const SAMPLE_BUDGET_MARGIN_MS = 3000;

export function getSamplingDeadlineMs(
  captureMs,
  {
    holdMs,
    settleMs,
    minFrames = MIN_SETTLED_FRAMES,
    floatPeriodMs = FLOAT_PERIOD_MS,
    maxHoldMs,
  },
) {
  const captureWindowMs = Math.max(minFrames * captureMs, floatPeriodMs) + captureMs + settleMs;
  return Math.min(maxHoldMs, Math.max(holdMs + 1000, captureWindowMs + SAMPLE_BUDGET_MARGIN_MS));
}

export function getSettledSamplingCoverage(
  frames,
  { settleMs, minFrames = MIN_SETTLED_FRAMES, floatPeriodMs = FLOAT_PERIOD_MS },
) {
  const settled = frames.filter((frame) => frame.t >= settleMs);
  const spanMs = settled.length > 1 ? settled.at(-1).t - settled[0].t : 0;
  return {
    count: settled.length,
    spanMs,
    complete: settled.length >= minFrames && spanMs >= floatPeriodMs,
  };
}
