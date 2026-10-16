// PRODUCT motion acceptance gate.
//
// Drives a REAL browser pointer over the PRODUCT tile gallery
// (tool/qa/product_motion_gallery_main.dart) and measures what is actually
// painted: the vertical position of each tile's content against its rest frame
// (sub-pixel), the accent shadow below it, whether it keeps floating while the
// pointer stays, and whether it returns to rest on exit. It does not read
// widget state, so a regression that leaves the widgets in place but paints
// nothing (reduced motion, a gated hover path, a dead hit-test) still fails.
//
//   flutter build web --release -t tool/qa/product_motion_gallery_main.dart \
//     --output build/motion-gallery
//   QA_WEB_ROOT=build/motion-gallery QA_BROWSER=chromium node scripts/qa/product_motion_acceptance.mjs
//   QA_REDUCED=1 ...   # reduced-motion contract: a still lift, no float
//
// Env: QA_WEB_ROOT, QA_LABEL, QA_BROWSER=chromium|firefox, QA_THEME=light|dark,
// QA_REDUCED=1, QA_PORT, QA_HOLD_MS (hover sampling window, default 3200).
//
// Real screens: QA_CASES_FILE=<json> measures tiles on the actual app instead
// of the gallery, either a local bundle (QA_WEB_ROOT, served offline) or a
// deployed site (QA_REMOTE_URL=https://...). The file is
//   { "route": "/", "clicks": [[x, y]], "scroll": 0,
//     "cases": [{ "id", "x", "y", "w", "h", "answer": "float|none" }] }
// with rectangles in CSS px of a 1440x900 viewport after the clicks/scroll.
// Output: output/playwright/product-motion/<label>/ (frames + report.json).
// Exit code 1 when any case fails.
import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { chromium, firefox } from 'playwright';
import {
  FLOAT_PERIOD_MS,
  MAX_PHASE_GAP_FRACTION,
  MIN_SETTLED_FRAMES,
  getNextSampleDelayMs,
  getSamplingDeadlineMs,
  getSettledSamplingCoverage,
} from './product_motion_sampling.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '../..');
const webRoot = path.resolve(rootDir, process.env.QA_WEB_ROOT || 'build/motion-gallery');
const browserName = process.env.QA_BROWSER || 'chromium';
const theme = process.env.QA_THEME || 'light';
const reduced = process.env.QA_REDUCED === '1';
const holdMs = Number(process.env.QA_HOLD_MS || 3200);
const port = Number(process.env.QA_PORT || 8101);
const label = (process.env.QA_LABEL || `${browserName}-${theme}${reduced ? '-reduced' : ''}`).trim();
const outDir = path.resolve(rootDir, 'output/playwright/product-motion', label);
const appUrl = `http://127.0.0.1:${port}`;
const VIEW = { width: 1440, height: 900 };
const DPR = 2;

// Same ids and rectangles as _cases in the gallery. `answer`:
//   'float' - interactive tile: lifts, floats, casts the accent shadow
//   'none'  - disabled tile: must stay completely still
const DEFAULT_CASES = [
  { id: 'action-stacked', x: 40, y: 60, w: 300, h: 140, answer: 'float' },
  { id: 'action-inline', x: 380, y: 60, w: 280, h: 56, answer: 'float' },
  { id: 'action-compact', x: 700, y: 60, w: 320, h: 64, answer: 'float' },
  { id: 'action-disabled', x: 1060, y: 60, w: 320, h: 64, answer: 'none' },
  { id: 'stat-centered', x: 40, y: 300, w: 300, h: 120, answer: 'float' },
  { id: 'stat-centered-tap', x: 380, y: 300, w: 300, h: 120, answer: 'float' },
  { id: 'stat-standard', x: 720, y: 300, w: 300, h: 88, answer: 'float' },
  { id: 'stat-standard-tap', x: 1060, y: 300, w: 300, h: 88, answer: 'float' },
  { id: 'stat-standard-expressive', x: 40, y: 540, w: 300, h: 88, answer: 'float' },
];

const casesFile = process.env.QA_CASES_FILE;
const spec = casesFile ? JSON.parse(await fs.readFile(path.resolve(casesFile), 'utf8')) : null;
const CASES = spec ? spec.cases : DEFAULT_CASES;
const remoteUrl = (process.env.QA_REMOTE_URL || '').replace(/\/$/, '');

// Pass thresholds, in CSS px / 0-255 mean channel difference.
const LIFT_MIN = 1.5; // mean rise while hovered
const FLOAT_MIN = 1.0; // peak-to-peak bob while the pointer stays (motion allowed)
const STILL_MAX = 0.6; // peak-to-peak when it must not move
const SHADOW_MIN = 1.2; // accent shadow below the tile
const REST_TOLERANCE = 0.6; // back at rest after exit
const SETTLE_MS = 600; // entry (180 ms) is over
const MAX_HOLD_MS = 90000;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.ico': 'image/x-icon',
};

function startServer() {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, appUrl);
    let rel = decodeURIComponent(url.pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(webRoot, rel);
    if (!file.startsWith(webRoot)) return res.writeHead(403).end();
    try {
      const stat = await fs.stat(file);
      if (stat.isDirectory()) file = path.join(file, 'index.html');
    } catch {
      file = path.join(webRoot, 'index.html');
    }
    try {
      const body = await fs.readFile(file);
      res.writeHead(200, {
        'content-type': MIME[path.extname(file)] || 'application/octet-stream',
        'cache-control': 'no-store',
      });
      res.end(body);
    } catch {
      res.writeHead(404).end();
    }
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}

// Runs inside a blank page: decodes PNG frames and measures them.
function analyseInPage({ restB64, frames, clip, rect, dpr }) {
  const load = (b64) =>
    new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        const c = document.createElement('canvas');
        c.width = img.width;
        c.height = img.height;
        const g = c.getContext('2d', { willReadFrequently: true });
        g.drawImage(img, 0, 0);
        resolve(g.getImageData(0, 0, img.width, img.height));
      };
      img.onerror = reject;
      img.src = `data:image/png;base64,${b64}`;
    });
  const gray = (d, i) => 0.299 * d.data[i] + 0.587 * d.data[i + 1] + 0.114 * d.data[i + 2];

  return (async () => {
    const rest = await load(restB64);
    const W = rest.width;
    // Content region, in clip-local device px: inside the hairline, away from
    // the corners, so the text carries the match and the shadow does not.
    const x0 = Math.round((rect.x - clip.x + 12) * dpr);
    const x1 = Math.round((rect.x - clip.x + rect.w - 12) * dpr);
    const y0 = Math.round((rect.y - clip.y + 8) * dpr);
    const y1 = Math.round((rect.y - clip.y + rect.h - 8) * dpr);
    // Shadow band: below the tile's resting bottom edge, beyond the 2-4 px the
    // lift itself can reveal.
    const b0 = Math.round((rect.y - clip.y + rect.h + 9) * dpr);
    const b1 = Math.round((rect.y - clip.y + rect.h + 22) * dpr);
    const bx0 = Math.round((rect.x - clip.x + 24) * dpr);
    const bx1 = Math.round((rect.x - clip.x + rect.w - 24) * dpr);
    const maxShift = 12 * dpr;

    const sad = (f, s) => {
      let sum = 0;
      let n = 0;
      for (let y = y0; y < y1; y += 1) {
        const fy = y + s;
        if (fy < 0 || fy >= f.height) continue;
        for (let x = x0; x < x1; x += 2) {
          sum += Math.abs(gray(rest, (y * W + x) * 4) - gray(f, (fy * W + x) * 4));
          n += 1;
        }
      }
      return n ? sum / n : Infinity;
    };
    const shadow = (f) => {
      let sum = 0;
      let n = 0;
      for (let y = b0; y < b1; y += 1) {
        for (let x = bx0; x < bx1; x += 2) {
          const i = (y * W + x) * 4;
          sum +=
            (Math.abs(rest.data[i] - f.data[i]) +
              Math.abs(rest.data[i + 1] - f.data[i + 1]) +
              Math.abs(rest.data[i + 2] - f.data[i + 2])) /
            3;
          n += 1;
        }
      }
      return n ? sum / n : 0;
    };

    const out = [];
    for (const fr of frames) {
      const f = await load(fr.b64);
      let best = 0;
      let bestV = Infinity;
      const costs = new Map();
      for (let s = -maxShift; s <= maxShift; s += 1) {
        const v = sad(f, s);
        costs.set(s, v);
        if (v < bestV) {
          bestV = v;
          best = s;
        }
      }
      // Parabolic refinement for a sub-device-pixel estimate.
      const a = costs.get(best - 1);
      const c = costs.get(best + 1);
      let sub = 0;
      if (a !== undefined && c !== undefined && Number.isFinite(a) && Number.isFinite(c)) {
        const denom = a - 2 * bestV + c;
        if (denom > 1e-6) sub = (a - c) / (2 * denom);
      }
      out.push({ t: fr.t, dy: (best + sub) / dpr, shadow: shadow(f) });
    }
    return out;
  })();
}

const stats = (xs) => ({
  mean: xs.reduce((a, b) => a + b, 0) / (xs.length || 1),
  min: Math.min(...xs),
  max: Math.max(...xs),
});

async function measureCase(page, helper, c) {
  const clip = {
    x: Math.max(0, c.x - 14),
    y: Math.max(0, c.y - 16),
    width: c.w + 28,
    height: c.h + 16 + 44,
  };
  const shot = async () => (await page.screenshot({ clip, type: 'png' })).toString('base64');
  const cx = c.x + c.w / 2;
  const cy = c.y + c.h / 2;

  await page.mouse.move(2, VIEW.height - 2);
  await page.waitForTimeout(700);
  const restB64 = await shot();

  await page.mouse.move(cx - 30, cy - 20);
  const t0 = Date.now();
  await page.mouse.move(cx, cy, { steps: 3 });
  const hoverFrames = [];
  const captureDurations = [];
  let sampleDeadlineMs = 25000;
  // Keep the 14-frame and full-period requirements. If Firefox captures are
  // slow under CI load, extend this window from measured latency up to 90 sec.
  // Firefox diagnostics recorded ~4.9 sec per capture: a 60 sec cap cannot
  // supply 14 painted samples. Sample counts and pixel thresholds stay fixed.
  while (true) {
    const elapsed = Date.now() - t0;
    const coverage = getSettledSamplingCoverage(hoverFrames, {
      settleMs: SETTLE_MS,
    });
    if (elapsed >= holdMs && coverage.complete) break;
    if (elapsed >= sampleDeadlineMs) break;
    // Slow browsers capture at a steady cadence that can be a whole number of
    // float periods; steer each capture to an unsampled phase so the settled
    // samples really cover the cycle. The pixel thresholds are untouched.
    const phaseDelayMs = hoverFrames.length
      ? getNextSampleDelayMs(hoverFrames, {
          settleMs: SETTLE_MS,
          nowMs: elapsed,
          expectedCaptureMs: captureDurations.at(-1) ?? 0,
        })
      : 0;
    if (phaseDelayMs) await page.waitForTimeout(phaseDelayMs);
    const captureStarted = Date.now();
    const b64 = await shot();
    const captureEnded = Date.now();
    const captureMs = captureEnded - captureStarted;
    captureDurations.push(captureMs);
    const recentCaptureMs = Math.max(...captureDurations.slice(-5));
    sampleDeadlineMs = Math.max(
      sampleDeadlineMs,
      getSamplingDeadlineMs(recentCaptureMs, {
        holdMs,
        settleMs: SETTLE_MS,
        maxHoldMs: MAX_HOLD_MS,
        phaseWaitMs: FLOAT_PERIOD_MS / 4,
      }),
    );
    hoverFrames.push({ t: (captureStarted + captureEnded) / 2 - t0, b64 });
  }

  await page.mouse.move(2, VIEW.height - 2, { steps: 3 });
  const t1 = Date.now();
  const exitFrames = [];
  while (Date.now() - t1 < 1200) {
    const b64 = await shot();
    exitFrames.push({ t: Date.now() - t1, b64 });
  }

  const measured = await helper.evaluate(analyseInPage, {
    restB64,
    frames: [...hoverFrames, ...exitFrames],
    clip: { x: clip.x, y: clip.y },
    rect: { x: c.x, y: c.y, w: c.w, h: c.h },
    dpr: DPR,
  });
  const hover = measured.slice(0, hoverFrames.length);
  const exit = measured.slice(hoverFrames.length);

  // Evidence frames: rest, the highest and the lowest point of the float.
  const settled = hover.map((m, i) => ({ ...m, i })).filter((m) => m.t >= SETTLE_MS);
  const evidenceFrames = settled.length ? settled : hover.map((m, i) => ({ ...m, i }));
  const high = evidenceFrames.reduce((a, b) => (b.dy < a.dy ? b : a), evidenceFrames[0]);
  const low = evidenceFrames.reduce((a, b) => (b.dy > a.dy ? b : a), evidenceFrames[0]);
  await fs.writeFile(path.join(outDir, `${c.id}-0-rest.png`), Buffer.from(restB64, 'base64'));
  if (high) {
    await fs.writeFile(path.join(outDir, `${c.id}-1-high.png`), Buffer.from(hoverFrames[high.i].b64, 'base64'));
    await fs.writeFile(path.join(outDir, `${c.id}-2-low.png`), Buffer.from(hoverFrames[low.i].b64, 'base64'));
  }

  const dys = settled.map((m) => m.dy);
  const shadows = settled.map((m) => m.shadow);
  const lift = stats(dys);
  const tail = exit.slice(-3);
  return {
    id: c.id,
    answer: c.answer,
    samples: hover.length,
    settledFrames: settled.length,
    settledSpanMs: settled.length > 1 ? settled.at(-1).t - settled[0].t : 0,
    captureMsMean: +stats(captureDurations).mean.toFixed(1),
    captureMsMax: Math.max(...captureDurations),
    maxPhaseGapMs: +getSettledSamplingCoverage(hoverFrames, { settleMs: SETTLE_MS }).maxPhaseGapMs.toFixed(0),
    sampleDeadlineMs,
    entry: hover.filter((m) => m.t < 400).map((m) => ({ t: m.t, dy: +m.dy.toFixed(2) })),
    liftMean: +lift.mean.toFixed(2),
    liftMin: +lift.min.toFixed(2),
    liftMax: +lift.max.toFixed(2),
    bob: +(lift.max - lift.min).toFixed(2),
    shadow: +stats(shadows).mean.toFixed(2),
    exitDy: +stats(tail.map((m) => m.dy)).mean.toFixed(2),
    exitShadow: +stats(tail.map((m) => m.shadow)).mean.toFixed(2),
  };
}

function judge(r) {
  const failures = [];
  if (r.settledFrames < MIN_SETTLED_FRAMES) {
    failures.push(`only ${r.settledFrames} settled pixel samples; need ${MIN_SETTLED_FRAMES}`);
  }
  if (r.maxPhaseGapMs > FLOAT_PERIOD_MS * MAX_PHASE_GAP_FRACTION) {
    failures.push(`samples leave a ${r.maxPhaseGapMs}ms hole in the ${FLOAT_PERIOD_MS}ms float phase`);
  }
  if (r.settledSpanMs < FLOAT_PERIOD_MS) {
    failures.push(`settled samples span ${r.settledSpanMs}ms; need a full ${FLOAT_PERIOD_MS}ms float period`);
  }
  if (r.answer === 'none') {
    if (Math.abs(r.liftMean) > STILL_MAX) failures.push(`moved ${r.liftMean}px but is disabled`);
    if (r.bob > STILL_MAX) failures.push(`bobbed ${r.bob}px but is disabled`);
    if (r.shadow > SHADOW_MIN / 2) failures.push(`cast a shadow (${r.shadow}) but is disabled`);
  } else {
    if (-r.liftMean < LIFT_MIN) failures.push(`lift ${-r.liftMean}px < ${LIFT_MIN}px`);
    if (r.shadow < SHADOW_MIN) failures.push(`accent shadow ${r.shadow} < ${SHADOW_MIN}`);
    if (reduced) {
      if (r.bob > STILL_MAX) failures.push(`reduced motion but it bobbed ${r.bob}px`);
    } else if (r.bob < FLOAT_MIN) {
      failures.push(`no continuous float: bob ${r.bob}px < ${FLOAT_MIN}px`);
    }
  }
  if (Math.abs(r.exitDy) > REST_TOLERANCE) failures.push(`did not return to rest (${r.exitDy}px)`);
  if (r.exitShadow > REST_TOLERANCE) failures.push(`shadow stayed after exit (${r.exitShadow})`);
  return failures;
}

async function main() {
  await fs.mkdir(outDir, { recursive: true });
  if (!remoteUrl) await fs.access(path.join(webRoot, 'main.dart.js'));
  const server = remoteUrl ? { close() {} } : await startServer();
  const browser = await (browserName === 'firefox' ? firefox : chromium).launch();
  const results = [];
  try {
    const context = await browser.newContext({
      viewport: VIEW,
      deviceScaleFactor: DPR,
      colorScheme: theme,
      reducedMotion: reduced ? 'reduce' : 'no-preference',
      locale: 'en-US',
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e.message || e)));
    if (spec) {
      if (!remoteUrl) {
        await page.routeWebSocket(/.*/, (ws) => ws.close());
        await page.route((url) => !url.toString().startsWith(appUrl), (r) =>
          r.fulfill({
            status: 503,
            headers: { 'access-control-allow-origin': appUrl, 'access-control-allow-credentials': 'true' },
            body: '',
          }),
        );
      }
      await page.addInitScript(() => {
        const set = (key, value) => localStorage.setItem(`flutter.${key}`, value);
        set('has_completed_onboarding', 'true');
        set('has_seen_welcome', 'true');
        set('is_first_launch', 'false');
        set('skipOnboardingForReturningUsers', 'true');
        set('map_onboarding_mobile_seen_v2', 'true');
        set('map_onboarding_desktop_seen_v2', 'true');
        set('selected_language', JSON.stringify('en'));
      });
    }
    const base = remoteUrl || appUrl;
    await page.goto(spec ? `${base}${spec.route || '/'}` : `${appUrl}/?theme=${theme}`, {
      waitUntil: 'domcontentloaded',
    });
    await page.waitForFunction(
      () => Boolean(document.querySelector('flutter-view') || document.querySelector('flt-glass-pane')),
      null,
      { timeout: 60000 },
    );
    await page.waitForTimeout(spec ? 8000 : 5000);
    if (spec) {
      for (const [x, y] of spec.clicks || []) {
        await page.mouse.click(x, y);
        await page.waitForTimeout(2500);
      }
      if (spec.scroll) {
        await page.mouse.move(VIEW.width / 2, VIEW.height / 2);
        await page.mouse.wheel(0, spec.scroll);
        await page.waitForTimeout(1200);
      }
    }
    const helper = await context.newPage();
    await helper.goto('about:blank');
    for (const c of CASES) {
      const r = await measureCase(page, helper, c);
      r.failures = judge(r);
      results.push(r);
      console.log(
        `${r.failures.length ? 'FAIL' : 'ok  '} ${browserName} ${theme}${reduced ? ' reduced' : ''} ${c.id}: ` +
          `lift ${-r.liftMean}px bob ${r.bob}px shadow ${r.shadow} exit ${r.exitDy}px/${r.exitShadow}` +
          (r.failures.length ? `  <- ${r.failures.join('; ')}` : ''),
      );
    }
    await context.close();
    const report = { label, browser: browserName, theme, reducedMotion: reduced, results, pageErrors: errors };
    await fs.writeFile(path.join(outDir, 'report.json'), `${JSON.stringify(report, null, 2)}\n`);
  } finally {
    await browser.close();
    server.close();
  }
  const failed = results.filter((r) => r.failures.length).length;
  console.log(`${results.length - failed}/${results.length} cases pass (${label})`);
  if (failed) process.exitCode = 1;
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
