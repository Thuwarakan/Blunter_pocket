#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Headless smoke test: write a .blend, re-open it, evaluate modifiers, render with Cycles.
#
#   run_smoke.sh <install-dir>          run locally (AArch64 host, or x86 + qemu binfmt)
#   ADB=1 run_smoke.sh <install-dir>    push to a device/emulator and run through adb
set -euo pipefail
install_dir=$(cd "${1:?usage: run_smoke.sh <install-dir>}" && pwd)
here=$(cd "$(dirname "$0")" && pwd)

if [[ "${ADB:-0}" == 1 ]]; then
  dev=/data/local/tmp/bla
  adb shell "rm -rf $dev && mkdir -p $dev/out"
  adb push "$install_dir" "$dev/install" >/dev/null
  adb push "$here/make_blend.py" "$here/check_blend.py" "$dev/" >/dev/null
  run() { adb shell "cd $dev && HOME=$dev/home $dev/install/blender $*"; }
  out=$dev/out; scripts=$dev
else
  work=$(mktemp -d)
  out=$work/out; mkdir -p "$out" "$work/home"
  run() { (cd "$work" && HOME=$work/home "$install_dir/blender" "$@"); }
  scripts=$here
fi

log1=$(run -b --factory-startup --python-exit-code 1 --python "$scripts/make_blend.py" -- "$out/test.blend" 2>&1) || true
echo "$log1"
grep -q '^SMOKE_SAVED' <<<"$log1" || { echo "smoke test FAILED: could not write .blend" >&2; exit 1; }

log2=$(run -b "$out/test.blend" --python-exit-code 1 --python "$scripts/check_blend.py" -- "$out" 2>&1) || true
echo "$log2"
grep -q '^SMOKE_OK' <<<"$log2" || { echo "smoke test FAILED" >&2; exit 1; }
echo "smoke test passed"
