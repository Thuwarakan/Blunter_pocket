#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Phase 2 on-device smoke test: install the APK, then run Blender in background mode
# through the activity's `args` extra (upstream BlenderActivity, debuggable builds):
#   1. write a .blend (tests/smoke/make_blend.py)
#   2. re-open it, check stdlib/NumPy/modifiers/booleans, render with Cycles CPU
#      (tests/smoke/check_blend.py)
# Output is read from logcat (tag "blender").
#
# Usage: tests/device/run_smoke.sh path/to/app-release.apk   (one device connected via adb)
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
apk=${1:?usage: run_smoke.sh <apk>}
# shellcheck source=../../branding/branding.env
source "$root/branding/branding.env"
component="$APP_ID/org.blender.blender.BlenderActivity"
data="/data/data/$APP_ID/files/smoke"

adb install -r "$apk"
# Scripts go into the app's private storage (the app cannot read /data/local/tmp).
adb shell run-as "$APP_ID" mkdir -p files/smoke/out
for f in make_blend.py check_blend.py; do
  adb shell run-as "$APP_ID" sh -c "'cat > files/smoke/$f'" < "$root/tests/smoke/$f"
done

run_step() {   # $1 = marker to wait for, rest = blender arguments
  local marker=$1; shift
  adb logcat -c
  adb shell am force-stop "$APP_ID"
  # NOTE: the args extra is whitespace-split upstream, so paths must not contain spaces.
  adb shell am start -W -n "$component" --es args "'$*'" >/dev/null

  for _ in $(seq 1 180); do
    if adb logcat -d -s blender | grep -q -E "$marker|SMOKE_FAILED|Traceback"; then break; fi
    sleep 2
  done
  adb logcat -d -s blender | sed 's/^.*blender *: //' | tee -a "$root/build/device-smoke.log"
  adb logcat -d -s blender | grep -q "$marker"
}

mkdir -p "$root/build"; : > "$root/build/device-smoke.log"
run_step SMOKE_SAVED -b --factory-startup --python-exit-code 1 \
  --python "$data/make_blend.py" -- "$data/out/test.blend"
run_step SMOKE_OK -b "$data/out/test.blend" --python-exit-code 1 \
  --python "$data/check_blend.py" -- "$data/out"
adb shell run-as "$APP_ID" ls -l files/smoke/out
echo "device smoke test passed (log: build/device-smoke.log)"
