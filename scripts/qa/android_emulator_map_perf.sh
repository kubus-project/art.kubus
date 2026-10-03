#!/usr/bin/env bash
# Wave 5B: Android map frame pacing on an EMULATOR (never a physical-device claim).
#
# Installs a signed release APK, waits for the map, drives it with scripted pans
# and a cluster-tap zoom, and derives frame intervals from SurfaceFlinger's
# per-layer present timestamps of the Flutter SurfaceView. (`dumpsys gfxinfo`
# reports 0 frames for Flutter: it does not draw through HWUI.)
#
#   scripts/qa/android_emulator_map_perf.sh <signed.apk> [label]
#
# Needs `adb` and `python3` (override with PYTHON=python) on PATH and a running emulator. Sign a release build
# with the debug key first:
#   apksigner sign --ks ~/.android/debug.keystore --ks-pass pass:android \
#     --key-pass pass:android app-release.apk
set -euo pipefail

apk="${1:?usage: android_emulator_map_perf.sh <signed.apk> [label]}"
label="${2:-run}"
pkg="com.art.kubus"
out="${QA_OUT:-output/playwright/spatial/android-perf}"
mkdir -p "$out"
samples="$out/$label-latency.txt"
: > "$samples"

adb shell svc power stayon true
adb shell input keyevent KEYCODE_WAKEUP
adb uninstall "$pkg" >/dev/null 2>&1 || true
adb install "$apk" | tail -1
adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

echo "waiting for the map to settle..."
sleep "${QA_SETTLE:-50}"
adb exec-out screencap -p > "$out/$label-opening.png"

# The Flutter view is a SurfaceView; its BLAST layer carries the presented frames.
layer="$(adb shell dumpsys SurfaceFlinger --list | tr -d '\r' | grep "SurfaceView\[$pkg/.*(BLAST)#" | head -1)"
echo "layer: $layer"

# The layer name contains brackets and parentheses, so quote it for the device shell.
sample() { adb shell "dumpsys SurfaceFlinger --latency '$layer'" | tr -d '\r' >> "$samples"; }

sample # discard-window start
for i in 1 2 3 4; do
  adb shell input swipe 300 1000 700 700 800 & sleep 0.9; sample; wait
  adb shell input swipe 700 700 300 1000 800 & sleep 0.9; sample; wait
done
adb shell input tap 560 1466
for i in 1 2 3 4 5 6; do sleep 0.8; sample; done
for i in 1 2; do
  adb shell input swipe 300 1100 700 600 800 & sleep 0.9; sample; wait
  adb shell input swipe 700 600 300 1100 800 & sleep 0.9; sample; wait
done
adb exec-out screencap -p > "$out/$label-after.png"

"${PYTHON:-python3}" - "$samples" "$label" <<'PY' | tee "$out/$label-frames.txt"
import sys
path, label = sys.argv[1], sys.argv[2]
present = set()
for line in open(path):
    parts = line.split()
    if len(parts) == 3 and parts[1].isdigit():
        value = int(parts[1])
        if 0 < value < 9_000_000_000_000_000_000:
            present.add(value)
ts = sorted(present)
deltas = [(b - a) / 1e6 for a, b in zip(ts, ts[1:])]
moving = [d for d in deltas if d < 250.0]   # drop idle gaps between swipes
moving.sort()
def q(p):
    return moving[min(len(moving) - 1, int(len(moving) * p))] if moving else float("nan")
print(f"{label}: frames={len(moving)} p50={q(.5):.1f}ms p90={q(.9):.1f}ms p95={q(.95):.1f}ms p99={q(.99):.1f}ms "
      f"over16.7={sum(d > 16.7 for d in moving)} over33={sum(d > 33.3 for d in moving)} over50={sum(d > 50 for d in moving)}")
PY
echo "device: $(adb shell getprop ro.product.model | tr -d '\r') android $(adb shell getprop ro.build.version.release | tr -d '\r') (EMULATOR, host GPU)"
