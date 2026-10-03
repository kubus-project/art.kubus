#!/usr/bin/env bash
# Wave 5B: controlled Android portrait <-> landscape reproduction (EMULATOR only).
#
# Installs a signed release APK on a freshly booted emulator, opens the map,
# optionally drives it into a fixed state, then rotates N times and records
# whether the app process survived and which fatal/platform-view/MapLibre lines
# reached logcat. Run it with the baseline APK and the branch APK on the same
# AVD to compare them.
#
#   scripts/qa/android_rotation_repro.sh <signed.apk> <label> [cycles]
#
# Env:
#   QA_SETTLE=50        seconds to let the map open before driving it
#   QA_STATE_TAPS="x,y x,y"  device-pixel taps applied once, in order, 3 s apart
#                       (e.g. a cluster tap and a marker tap) to reach a fixed state
#   QA_ROTATE_WAIT=3    seconds to rest after each rotation
#   QA_OUT=output/playwright/spatial/android-rotation
#
# Exit status: 0 when the app survived every cycle, 1 when it died.
set -uo pipefail

apk="${1:?usage: android_rotation_repro.sh <signed.apk> <label> [cycles]}"
label="${2:?label}"
cycles="${3:-20}"
pkg="com.art.kubus"
out="${QA_OUT:-output/playwright/spatial/android-rotation}"
mkdir -p "$out"
logfile="$out/$label-logcat.txt"
summary="$out/$label-summary.txt"

pid_of() { adb shell pidof "$pkg" 2>/dev/null | tr -d '\r' | awk '{print $1}'; }

adb shell svc power stayon true
adb shell input keyevent KEYCODE_WAKEUP
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb uninstall "$pkg" >/dev/null 2>&1 || true
adb install "$apk" | tail -1
adb logcat -c
adb shell monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep "${QA_SETTLE:-50}"

start_pid="$(pid_of)"
echo "start pid: ${start_pid:-none}"
if [ -z "$start_pid" ]; then
  echo "$label: app not running after launch" | tee "$summary"
  exit 1
fi

for tap in ${QA_STATE_TAPS:-}; do
  adb shell input tap "${tap%,*}" "${tap#*,}"
  sleep 3
done
adb exec-out screencap -p > "$out/$label-state.png"

died_at=0
for i in $(seq 1 "$cycles"); do
  adb shell settings put system user_rotation 1
  sleep "${QA_ROTATE_WAIT:-3}"
  adb shell settings put system user_rotation 0
  sleep "${QA_ROTATE_WAIT:-3}"
  now="$(pid_of)"
  if [ "$now" != "$start_pid" ]; then
    died_at="$i"
    echo "cycle $i: pid changed (${now:-gone})"
    break
  fi
done
adb exec-out screencap -p > "$out/$label-end.png"
adb logcat -d > "$logfile"

count() { grep -c -E "$1" "$logfile" || true; }
{
  echo "$label: cycles requested=$cycles, completed=$([ "$died_at" = 0 ] && echo "$cycles" || echo $((died_at - 1))), died_at_cycle=$died_at"
  echo "  FATAL EXCEPTION            : $(count 'FATAL EXCEPTION')"
  echo "  PlatformViewsController    : $(count 'PlatformViewsController')"
  echo "  SurfaceProducer...getWidth : $(count 'SurfaceProducerPlatformViewRenderTarget')"
  echo "  NullPointerException       : $(count 'NullPointerException')"
  echo "  ActivityManager death      : $(count "Process $pkg.*has died|Force finishing activity.*$pkg")"
  echo "  MapLibre native errors     : $(count 'E/(Mbgl|maplibre)|MapLibre.*(error|Error)')"
  echo "  device: $(adb shell getprop ro.product.model | tr -d '\r') android $(adb shell getprop ro.build.version.release | tr -d '\r') (EMULATOR)"
} | tee "$summary"
[ "$died_at" = 0 ]
