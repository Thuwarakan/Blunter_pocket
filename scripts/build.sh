#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Single entry point for the Android build.
#
#   scripts/build.sh fetch-blender   clone the pinned upstream Blender + apply patches/blender
#   scripts/build.sh deps            cross-compile the third-party libraries (deps/)
#   scripts/build.sh blender         configure + build + install the headless Blender
#   scripts/build.sh smoke           run the headless smoke test (qemu-aarch64 or device)
#   scripts/build.sh all             everything above, in order
#
# Environment:
#   ANDROID_NDK_ROOT   NDK r27+ (GitHub runners: ANDROID_NDK_LATEST_HOME is used)
#   BLA_BUILD          build root (default: <repo>/build)
#   BLA_JOBS           parallel jobs (default: nproc)
#
# Build-machine requirements: cmake >= 3.28, ninja, meson, pkg-config, python3.13,
# patch, and qemu-user-static registered with binfmt_misc (Blender's code generators
# are compiled for the target and executed during the build).

set -euo pipefail
BLA_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export BLA_ROOT
# shellcheck source=../deps/lib.sh
source "$BLA_ROOT/deps/lib.sh"
# shellcheck source=../upstream/blender.lock
source "$BLA_ROOT/upstream/blender.lock"

BLENDER_BUILD_DIR=${BLENDER_BUILD_DIR:-$BLA_BUILD/blender-headless}
BLENDER_INSTALL_DIR=${BLENDER_INSTALL_DIR:-$BLA_BUILD/install/headless}

cmd_fetch_blender() {
  if [[ ! -d "$BLENDER_SRC/.git" ]]; then
    log "cloning Blender $BLENDER_TAG"
    git clone --depth 1 --branch "$BLENDER_TAG" "$BLENDER_GIT_URL" "$BLENDER_SRC"
  fi
  local head; head=$(git -C "$BLENDER_SRC" rev-parse HEAD)
  [[ "$head" == "$BLENDER_COMMIT" ]] || die "Blender checkout is at $head, expected $BLENDER_COMMIT"

  # Apply our upstream patch series exactly once (reset first so re-runs are clean).
  git -C "$BLENDER_SRC" checkout -q -- .
  local p
  for p in "$BLA_ROOT"/patches/blender/*.patch; do
    [[ -e "$p" ]] || continue
    log "apply $(basename "$p")"
    git -C "$BLENDER_SRC" apply --whitespace=nowarn "$p"
  done
}

cmd_deps() {
  "$BLA_ROOT/deps/build_deps.sh" "$@"
}

check_binfmt() {
  if [[ -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then return 0; fi
  if command -v qemu-aarch64-static >/dev/null || command -v qemu-aarch64 >/dev/null; then
    die "qemu-aarch64 is installed but not registered with binfmt_misc
    (Debian/Ubuntu: sudo apt-get install qemu-user-static binfmt-support)"
  fi
  [[ "$(uname -m)" == aarch64 ]] && return 0
  die "Blender's build-time tools are AArch64 executables; install qemu-user-static
    (Debian/Ubuntu: sudo apt-get install qemu-user-static binfmt-support)"
}

host_python() {
  command -v python3.13 || die "python3.13 is required on the build machine"
}

cmd_blender() {
  setup_toolchain
  check_binfmt
  [[ -f "$LIBDIR/python/link_deps.txt" ]] || die "dependencies not built (run: scripts/build.sh deps)"

  local launcher=()
  if command -v ccache >/dev/null; then
    launcher=(-DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache)
  fi
  cmake -S "$BLENDER_SRC" -B "$BLENDER_BUILD_DIR" -G Ninja \
    -C "$BLA_ROOT/android/cmake/blender_headless.cmake" \
    "${launcher[@]}" \
    -DLIBDIR="$LIBDIR" \
    -DHOST_PYTHON="$(host_python)" \
    -DCMAKE_TOOLCHAIN_FILE="$BLA_TOOLCHAIN_FILE" \
    -DANDROID_ABI="$ANDROID_ABI" \
    -DANDROID_PLATFORM="android-$ANDROID_API" \
    -DANDROID_STL=c++_static \
    -DBLA_LIBDIR="$LIBDIR" \
    -DCMAKE_INSTALL_PREFIX="$BLENDER_INSTALL_DIR" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5

  cmake --build "$BLENDER_BUILD_DIR" -j "$BLA_JOBS"
  cmake --install "$BLENDER_BUILD_DIR"
  "$READELF" -h "$BLENDER_INSTALL_DIR/blender" | grep -E 'Machine|Type'
  log "installed to $BLENDER_INSTALL_DIR"
}

cmd_smoke() {
  "$BLA_ROOT/tests/smoke/run_smoke.sh" "$BLENDER_INSTALL_DIR"
}

case "${1:-}" in
  fetch-blender) cmd_fetch_blender ;;
  deps) shift; cmd_deps "$@" ;;
  blender) cmd_blender ;;
  smoke) cmd_smoke ;;
  all) cmd_fetch_blender; cmd_deps; cmd_blender; cmd_smoke ;;
  *) sed -n '3,20p' "$0"; exit 1 ;;
esac
