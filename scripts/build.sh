#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Single entry point: build the Android APK from Blender's official `android` branch
# (pinned in upstream/blender.lock) plus this project's patches and branding.
#
#   scripts/build.sh fetch     check out upstream, pre-built libs, apply patches + branding
#   scripts/build.sh blender   cross-compile libblender.so (+ host code generators)
#   scripts/build.sh apk       stage + assemble the APK with Gradle
#   scripts/build.sh all       all of the above
#
# Environment:
#   BLA_BUILD          build root (default: <repo>/build)
#   ANDROID_HOME       Android SDK (Gradle, platform android-36)
#   ANDROID_NDK_ROOT   NDK; if unset, upstream picks the newest one in $ANDROID_HOME/ndk
#   JAVA_HOME          JDK 17+ for Gradle / Android Gradle Plugin 9
#   BLA_ABI            arm64 (default) or x64
#   BLA_JOBS           parallel jobs (default: nproc)
#
# Network: projects.blender.org (pre-built libraries via Git LFS), Maven/Google for Gradle.

set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../upstream/blender.lock
source "$root/upstream/blender.lock"

BLA_BUILD=${BLA_BUILD:-$root/build}
BLENDER_SRC=${BLENDER_SRC:-$BLA_BUILD/blender}
BLA_ABI=${BLA_ABI:-arm64}
BLA_JOBS=${BLA_JOBS:-$(nproc)}
BUILD_DIR=${BUILD_DIR:-$BLA_BUILD/build_android_${BLA_ABI}}

log() { printf '\033[1;34m[build]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[build] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# projects.blender.org serves public LFS content but may ask for credentials; answer with
# empty ones so unattended runs never hang on a prompt (scoped to that host only).
GIT_PB=(-c "credential.https://projects.blender.org.helper=!f() { echo username=; echo password=; }; f")
export GIT_TERMINAL_PROMPT=0

host_lib_dir() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) echo lib/linux_x64 ;;
    Linux-aarch64) echo lib/linux_arm64 ;;
    Darwin-arm64) echo lib/macos_arm64 ;;
    *) die "unsupported build host $(uname -s)-$(uname -m)" ;;
  esac
}

cmd_fetch() {
  command -v git-lfs >/dev/null || die "git-lfs is required (pre-built libraries are LFS objects)"
  if [[ ! -d "$BLENDER_SRC/.git" ]]; then
    log "fetching Blender $BLENDER_BRANCH @ ${BLENDER_COMMIT:0:10}"
    git init -q "$BLENDER_SRC"
    git -C "$BLENDER_SRC" remote add origin "$BLENDER_GIT_URL"
    # Pinned commit by SHA: try projects.blender.org, then the GitHub mirror.
    git "${GIT_PB[@]}" -C "$BLENDER_SRC" fetch -q --depth 1 origin "$BLENDER_COMMIT" \
      || git -C "$BLENDER_SRC" fetch -q --depth 1 "$BLENDER_GIT_MIRROR" "$BLENDER_COMMIT" \
      || die "could not fetch $BLENDER_COMMIT"
    git -C "$BLENDER_SRC" -c advice.detachedHead=false checkout -q FETCH_HEAD
  fi
  local head; head=$(git -C "$BLENDER_SRC" rev-parse HEAD)
  [[ "$head" == "$BLENDER_COMMIT" ]] || die "checkout is at $head, expected $BLENDER_COMMIT"

  # Upstream LFS objects of the main repository (icons, fonts, ...).
  git -C "$BLENDER_SRC" config lfs.url "${BLENDER_GIT_URL}/info/lfs"
  git "${GIT_PB[@]}" -C "$BLENDER_SRC" lfs pull

  # Pre-built libraries: the Android target set and the build host's set (the host
  # Python and code-generator libraries used while cross-compiling).
  local target_libs=lib/android_arm64
  [[ "$BLA_ABI" == x64 ]] && target_libs=lib/android_x64
  local libs
  for libs in "$target_libs" "$(host_lib_dir)"; do
    log "submodule $libs"
    git "${GIT_PB[@]}" -C "$BLENDER_SRC" submodule update --init --depth 1 "$libs"
    git "${GIT_PB[@]}" -C "$BLENDER_SRC/$libs" lfs pull
  done

  # Our changes on top of upstream: reset first so re-runs apply cleanly.
  git -C "$BLENDER_SRC" checkout -q -- . && git -C "$BLENDER_SRC" clean -q -fd -- release/android
  local p
  for p in "$root"/patches/blender/*.patch; do
    [[ -e "$p" ]] || continue
    log "apply $(basename "$p")"
    git -C "$BLENDER_SRC" apply --whitespace=nowarn "$p"
  done
  "$root/scripts/apply_branding.sh" "$BLENDER_SRC"
}

cmd_blender() {
  [[ -d "$BLENDER_SRC/lib/android_${BLA_ABI}" ]] || die "run: scripts/build.sh fetch"
  local extra=()
  [[ -n "${ANDROID_NDK_ROOT:-}" ]] && extra+=(ANDROID_NDK_ROOT="$ANDROID_NDK_ROOT")
  command -v ninja >/dev/null && extra+=(ninja)
  command -v ccache >/dev/null && extra+=(ccache)
  log "building libblender.so in $BUILD_DIR"
  # Upstream's GNUmakefile handles the toolchain file, host code generators and LIBDIR.
  make -C "$BLENDER_SRC" android "$BLA_ABI" BUILD_DIR="$BUILD_DIR" \
    NPROCS="$BLA_JOBS" "${extra[@]}"
}

cmd_apk() {
  [[ -f "$BUILD_DIR/CMakeCache.txt" ]] || die "run: scripts/build.sh blender"
  [[ -n "${JAVA_HOME:-}" ]] || die "JAVA_HOME must point to a JDK 17+"
  cmake --build "$BUILD_DIR" --target gradle_assemble
  local apk
  apk=$(find "$BUILD_DIR/gradle/app/build/outputs/apk" -name '*.apk' | head -1)
  [[ -n "$apk" ]] || die "no APK produced"
  mkdir -p "$BLA_BUILD/out"
  cp "$apk" "$BLA_BUILD/out/"
  log "APK: $BLA_BUILD/out/$(basename "$apk") ($(du -h "$apk" | cut -f1))"
}

case "${1:-}" in
  fetch) cmd_fetch ;;
  blender) cmd_blender ;;
  apk) cmd_apk ;;
  all) cmd_fetch; cmd_blender; cmd_apk ;;
  *) sed -n '3,22p' "$0"; exit 1 ;;
esac
