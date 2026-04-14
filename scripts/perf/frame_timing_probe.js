/*
 * Kubus desktop-web frame timing probe
 * Usage in Chrome DevTools Console (or Sources > Snippets):
 * 1) Paste/run this file once per tab.
 * 2) Start capture:
 *      kubusFrameProbe.start({ label: 'before', durationMs: 60000 });
 * 3) Run your test scenario. The probe auto-stops at durationMs.
 * 4) Optional manual stop:
 *      kubusFrameProbe.stop();
 * 5) Copy the printed JSON summary from the console.
 */
(() => {
  const state = {
    running: false,
    label: null,
    startTs: 0,
    lastTs: 0,
    rafId: null,
    timeoutId: null,
    frameDeltas: [],
    longTasks: [],
    observer: null,
  };

  function percentile(values, p) {
    if (!values.length) return 0;
    const sorted = [...values].sort((a, b) => a - b);
    const idx = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
    return sorted[idx];
  }

  function buildSummary() {
    const deltas = state.frameDeltas;
    const totalDurationMs = deltas.reduce((sum, v) => sum + v, 0);
    const avgFrameMs = deltas.length ? totalDurationMs / deltas.length : 0;
    const fpsApprox = avgFrameMs > 0 ? 1000 / avgFrameMs : 0;
    const over16_7 = deltas.filter((v) => v > 16.7).length;
    const over33_3 = deltas.filter((v) => v > 33.3).length;
    const over50 = deltas.filter((v) => v > 50).length;
    const longTaskCount = state.longTasks.length;
    const longTaskTotalMs = state.longTasks.reduce((sum, t) => sum + t.duration, 0);

    const memory = typeof performance !== 'undefined' && performance.memory
      ? {
          usedJSHeapSize: performance.memory.usedJSHeapSize,
          totalJSHeapSize: performance.memory.totalJSHeapSize,
          jsHeapSizeLimit: performance.memory.jsHeapSizeLimit,
        }
      : null;

    return {
      label: state.label,
      startedAtIso: new Date(state.startTs).toISOString(),
      endedAtIso: new Date().toISOString(),
      durationMs: Number(totalDurationMs.toFixed(2)),
      frames: deltas.length,
      fpsApprox: Number(fpsApprox.toFixed(2)),
      frameMs: {
        avg: Number(avgFrameMs.toFixed(2)),
        p50: Number(percentile(deltas, 50).toFixed(2)),
        p95: Number(percentile(deltas, 95).toFixed(2)),
        p99: Number(percentile(deltas, 99).toFixed(2)),
        max: Number((deltas.length ? Math.max(...deltas) : 0).toFixed(2)),
      },
      jank: {
        over16_7ms: over16_7,
        over33_3ms: over33_3,
        over50ms: over50,
        over16_7Pct: deltas.length ? Number(((over16_7 / deltas.length) * 100).toFixed(2)) : 0,
      },
      longTasks: {
        count: longTaskCount,
        totalDurationMs: Number(longTaskTotalMs.toFixed(2)),
      },
      memory,
    };
  }

  function cleanupTimers() {
    if (state.rafId !== null) {
      cancelAnimationFrame(state.rafId);
      state.rafId = null;
    }
    if (state.timeoutId !== null) {
      clearTimeout(state.timeoutId);
      state.timeoutId = null;
    }
  }

  function stop() {
    if (!state.running) {
      console.warn('kubusFrameProbe.stop: probe is not running.');
      return null;
    }

    state.running = false;
    cleanupTimers();

    if (state.observer) {
      try {
        state.observer.disconnect();
      } catch (_e) {
        // no-op
      }
      state.observer = null;
    }

    const summary = buildSummary();
    console.log('kubusFrameProbe summary', summary);
    console.log('kubusFrameProbe summary JSON', JSON.stringify(summary, null, 2));
    return summary;
  }

  function tick(ts) {
    if (!state.running) return;

    if (state.lastTs > 0) {
      state.frameDeltas.push(ts - state.lastTs);
    }
    state.lastTs = ts;
    state.rafId = requestAnimationFrame(tick);
  }

  function start(options = {}) {
    if (state.running) {
      console.warn('kubusFrameProbe.start: probe already running. Stopping previous run first.');
      stop();
    }

    const durationMs = Number.isFinite(options.durationMs) ? options.durationMs : 60000;
    const label = typeof options.label === 'string' && options.label.trim().length > 0
      ? options.label.trim()
      : 'run';

    state.running = true;
    state.label = label;
    state.startTs = Date.now();
    state.lastTs = 0;
    state.frameDeltas = [];
    state.longTasks = [];

    if (typeof PerformanceObserver !== 'undefined') {
      try {
        state.observer = new PerformanceObserver((entryList) => {
          const entries = entryList.getEntries();
          for (const entry of entries) {
            state.longTasks.push({
              startTime: Number(entry.startTime.toFixed(2)),
              duration: Number(entry.duration.toFixed(2)),
            });
          }
        });
        state.observer.observe({ entryTypes: ['longtask'] });
      } catch (_e) {
        state.observer = null;
      }
    }

    state.rafId = requestAnimationFrame(tick);
    state.timeoutId = setTimeout(() => {
      stop();
    }, durationMs);

    console.log(`kubusFrameProbe started: label=${label}, durationMs=${durationMs}`);
    return true;
  }

  window.kubusFrameProbe = { start, stop };
  console.log('kubusFrameProbe loaded. Example: kubusFrameProbe.start({ label: "before", durationMs: 60000 });');
})();
