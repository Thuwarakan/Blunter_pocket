# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Shared helpers for cross-compiling Blender's third-party libraries with the
# Android NDK. Sourced by deps/build_deps.sh and by every recipe in deps/recipes/.
#
# Layout (all overridable through the environment):
#   $BLA_ROOT              repository root
#   $BLA_BUILD             build root                   (default: $BLA_ROOT/build)
#   $BLENDER_SRC           upstream Blender checkout    (default: $BLA_BUILD/blender)
#   $BLA_DOWNLOADS         downloaded source archives   (default: $BLA_BUILD/downloads)
#   $BLA_WORK              per-library build trees      (default: $BLA_BUILD/deps-work)
#   $LIBDIR                install root, one sub-folder per library, same layout as
#                          Blender's precompiled lib/<platform> folders
#                          (default: $BLA_BUILD/lib/android_arm64)

set -euo pipefail

BLA_ROOT=${BLA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
BLA_BUILD=${BLA_BUILD:-$BLA_ROOT/build}
BLENDER_SRC=${BLENDER_SRC:-$BLA_BUILD/blender}
BLA_DOWNLOADS=${BLA_DOWNLOADS:-$BLA_BUILD/downloads}
BLA_WORK=${BLA_WORK:-$BLA_BUILD/deps-work}
LIBDIR=${LIBDIR:-$BLA_BUILD/lib/android_arm64}
BLA_JOBS=${BLA_JOBS:-$(nproc)}

# Android target. API 29 == Android 10 (also the first level where bionic supports
# ELF TLS in static executables, which the headless static build relies on).
ANDROID_API=${ANDROID_API:-29}
ANDROID_ABI=arm64-v8a
TARGET_TRIPLE=aarch64-linux-android

BLENDER_VERSIONS_CMAKE=$BLENDER_SRC/build_files/build_environment/cmake/versions.cmake
BLENDER_DEPS_PATCHES=$BLENDER_SRC/build_files/build_environment/patches

log()  { printf '\033[1;34m[deps]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[deps] WARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[deps] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# NDK / toolchain

find_ndk() {
  local cand
  for cand in "${ANDROID_NDK_ROOT:-}" "${ANDROID_NDK_HOME:-}" "${ANDROID_NDK_LATEST_HOME:-}" \
              "${ANDROID_NDK:-}"; do
    if [[ -n "$cand" && -f "$cand/source.properties" ]]; then
      echo "$cand"; return 0
    fi
  done
  # Newest NDK inside an SDK installation.
  for cand in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}"; do
    if [[ -n "$cand" && -d "$cand/ndk" ]]; then
      cand=$(ls -d "$cand"/ndk/*/ 2>/dev/null | sort -V | tail -1)
      [[ -n "$cand" ]] && { echo "${cand%/}"; return 0; }
    fi
  done
  return 1
}

setup_toolchain() {
  NDK=$(find_ndk) || die "Android NDK not found. Set ANDROID_NDK_ROOT (NDK r27 or newer)."
  local rev major
  rev=$(sed -n 's/^Pkg.Revision *= *//p' "$NDK/source.properties")
  major=${rev%%.*}
  (( major >= 27 )) || die "NDK r27+ required, found $rev at $NDK"
  NDK_REVISION=$rev
  export NDK NDK_REVISION

  TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64
  SYSROOT=$TOOLCHAIN/sysroot
  [[ -d "$TOOLCHAIN" ]] || die "NDK toolchain missing: $TOOLCHAIN"

  export CC="$TOOLCHAIN/bin/${TARGET_TRIPLE}${ANDROID_API}-clang"
  export CXX="$TOOLCHAIN/bin/${TARGET_TRIPLE}${ANDROID_API}-clang++"
  export AR="$TOOLCHAIN/bin/llvm-ar"
  export AS="$CC"
  export LD="$TOOLCHAIN/bin/ld.lld"
  export NM="$TOOLCHAIN/bin/llvm-nm"
  export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
  export STRIP="$TOOLCHAIN/bin/llvm-strip"
  export READELF="$TOOLCHAIN/bin/llvm-readelf"
  export OBJCOPY="$TOOLCHAIN/bin/llvm-objcopy"

  # Common flags. 16 KB max-page-size is required for Android 15+ devices with
  # 16 KB pages (and by Google Play); __BIONIC_NO_PAGE_SIZE_MACRO follows CPython's
  # Android build so nothing hard-codes PAGE_SIZE = 4096.
  BLA_CFLAGS="-fPIC -O2 -DNDEBUG -ffunction-sections -fdata-sections -D__BIONIC_NO_PAGE_SIZE_MACRO"
  BLA_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,--build-id=sha1"

  export BLA_TOOLCHAIN_FILE=$BLA_ROOT/deps/toolchain/android-arm64.cmake
  log "NDK $NDK_REVISION at $NDK, API $ANDROID_API"
}

# -----------------------------------------------------------------------------
# Library search paths of everything already installed in $LIBDIR.

installed_prefixes() {
  local d
  for d in "$LIBDIR"/*/; do
    [[ -d "$d" ]] && echo "${d%/}"
  done
}

join_by() { local IFS="$1"; shift; echo "$*"; }

# Prefix list for CMAKE_PREFIX_PATH (';' separated).
cmake_prefix_path() { join_by ';' $(installed_prefixes); }

# -I/-L flags and pkg-config dirs for autotools / meson builds.
dep_cppflags() {
  local p out=""
  for p in $(installed_prefixes); do [[ -d "$p/include" ]] && out+=" -I$p/include"; done
  echo "$out"
}
dep_ldflags() {
  local p out=""
  for p in $(installed_prefixes); do
    [[ -d "$p/lib" ]] && out+=" -L$p/lib"
  done
  echo "$out"
}
dep_pkgconfig_libdir() {
  local p dirs=()
  for p in $(installed_prefixes); do
    [[ -d "$p/lib/pkgconfig" ]] && dirs+=("$p/lib/pkgconfig")
    [[ -d "$p/share/pkgconfig" ]] && dirs+=("$p/share/pkgconfig")
  done
  join_by ':' "${dirs[@]+"${dirs[@]}"}"
}

# -----------------------------------------------------------------------------
# Sources

# Load DEP_VERSION/DEP_URI/DEP_FILE/DEP_HASH/DEP_HASH_TYPE for a Blender dependency
# name (the prefix used in versions.cmake, e.g. ZLIB, OPENIMAGEIO).
dep_info() {
  local name=$1
  [[ -f "$BLENDER_VERSIONS_CMAKE" ]] || die "Blender source not found at $BLENDER_SRC (run scripts/build.sh fetch-blender)"
  unset DEP_VERSION DEP_URI DEP_FILE DEP_HASH DEP_HASH_TYPE
  eval "$(cmake -DVERSIONS="$BLENDER_VERSIONS_CMAKE" -DDEP="$name" -P "$BLA_ROOT/deps/tools/dep_info.cmake")"
  [[ -n "${DEP_FILE:-}" ]] || die "$name: no ${name}_FILE in versions.cmake"
}

verify_hash() {
  local file=$1 type=$2 expected=$3 actual
  case "$type" in
    MD5)    actual=$(md5sum "$file" | cut -d' ' -f1) ;;
    SHA256) actual=$(sha256sum "$file" | cut -d' ' -f1) ;;
    SHA512) actual=$(sha512sum "$file" | cut -d' ' -f1) ;;
    *) die "unknown hash type $type" ;;
  esac
  [[ "$actual" == "$expected" ]]
}

# Download the source archive of a Blender dependency (verified against the hash
# pinned in versions.cmake). Tries Blender's own source mirror first, then upstream.
fetch() {
  local name=$1
  dep_info "$name"
  mkdir -p "$BLA_DOWNLOADS"
  local out=$BLA_DOWNLOADS/$DEP_FILE
  if [[ -f "$out" ]] && verify_hash "$out" "$DEP_HASH_TYPE" "$DEP_HASH"; then
    echo "$out"; return 0
  fi
  local blender_series url
  blender_series=$(sed -n 's/^set(BLENDER_VERSION \([0-9.]*\)).*/\1/p' \
    "$BLENDER_SRC/build_files/build_environment/cmake/download.cmake")
  for url in \
      "https://projects.blender.org/blender/lib-source/media/branch/blender-v${blender_series}-release/${DEP_FILE}" \
      "$DEP_URI"; do
    log "fetch $name: $url"
    if curl -fL --retry 4 --retry-delay 5 --connect-timeout 30 -o "$out.part" "$url"; then
      if verify_hash "$out.part" "$DEP_HASH_TYPE" "$DEP_HASH"; then
        mv "$out.part" "$out"; echo "$out"; return 0
      fi
      warn "$name: hash mismatch for $url"
    fi
    rm -f "$out.part"
  done
  die "$name: could not download $DEP_FILE"
}

# Fetch + extract into a fresh $BLA_WORK/<lib>/src and cd there.
# Usage: unpack <BLENDER_DEP_NAME> [<lib-dir-name>]
unpack() {
  local name=$1 lib=${2:-${RECIPE_NAME}}
  local archive; archive=$(fetch "$name")
  dep_info "$name"   # fetch ran in a subshell; make DEP_VERSION etc. visible to the recipe
  SRC_DIR=$BLA_WORK/$lib/src
  BUILD_DIR=$BLA_WORK/$lib/build
  rm -rf "${BLA_WORK:?}/${lib:?}"
  mkdir -p "$SRC_DIR" "$BUILD_DIR"
  log "unpack $(basename "$archive")"
  case "$archive" in
    *.zip) unzip -q "$archive" -d "$SRC_DIR.tmp" ;;
    *)     mkdir -p "$SRC_DIR.tmp" && tar -xf "$archive" -C "$SRC_DIR.tmp" ;;
  esac
  # Strip the single top-level folder if there is one.
  local entries; entries=$(ls -A "$SRC_DIR.tmp")
  if [[ $(echo "$entries" | wc -l) -eq 1 && -d "$SRC_DIR.tmp/$entries" ]]; then
    rm -rf "${SRC_DIR:?}"; mv "$SRC_DIR.tmp/$entries" "$SRC_DIR"; rmdir "$SRC_DIR.tmp"
  else
    rm -rf "${SRC_DIR:?}"; mv "$SRC_DIR.tmp" "$SRC_DIR"
  fi
  cd "$SRC_DIR"
}

# Apply one of Blender's own dependency patches (build_environment/patches/<file>).
apply_blender_patch() {
  local p=$BLENDER_DEPS_PATCHES/$1
  [[ -f "$p" ]] || die "missing Blender patch $1"
  log "patch (blender) $1"
  patch -p1 -N -d "$SRC_DIR" < "$p" >/dev/null
}

# Apply one of our Android patches (deps/patches/<file>).
apply_android_patch() {
  local p=$BLA_ROOT/deps/patches/$1
  [[ -f "$p" ]] || die "missing Android patch $1"
  log "patch (android) $1"
  patch -p1 -N -d "$SRC_DIR" < "$p" >/dev/null
}

# -----------------------------------------------------------------------------
# Build-system helpers. All install into $PREFIX (= $LIBDIR/<lib>).

cmake_build() {
  # Usage: cmake_build [extra cmake args...]   (source dir = $CMAKE_SOURCE_SUBDIR or .)
  local src=$SRC_DIR/${CMAKE_SOURCE_SUBDIR:-}
  cmake -S "$src" -B "$BUILD_DIR" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$BLA_TOOLCHAIN_FILE" \
    -DANDROID_ABI="$ANDROID_ABI" \
    -DANDROID_PLATFORM="android-$ANDROID_API" \
    -DANDROID_STL=c++_static \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_PREFIX_PATH="$(cmake_prefix_path)" \
    -DBLA_LIBDIR="$LIBDIR" \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_C_FLAGS="$BLA_CFLAGS ${EXTRA_CFLAGS:-}" \
    -DCMAKE_CXX_FLAGS="$BLA_CFLAGS ${EXTRA_CXXFLAGS:-}" \
    -DCMAKE_EXE_LINKER_FLAGS="$BLA_LDFLAGS" \
    -DCMAKE_SHARED_LINKER_FLAGS="$BLA_LDFLAGS" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -Wno-dev \
    "$@"
  cmake --build "$BUILD_DIR" -j "$BLA_JOBS"
  cmake --install "$BUILD_DIR"
}

# Environment for autotools / plain-make projects.
autotools_env() {
  export CFLAGS="$BLA_CFLAGS $(dep_cppflags) ${EXTRA_CFLAGS:-}"
  export CXXFLAGS="$BLA_CFLAGS $(dep_cppflags) ${EXTRA_CXXFLAGS:-}"
  export CPPFLAGS="$(dep_cppflags)"
  export LDFLAGS="$BLA_LDFLAGS $(dep_ldflags) ${EXTRA_LDFLAGS:-}"
  export PKG_CONFIG_LIBDIR; PKG_CONFIG_LIBDIR=$(dep_pkgconfig_libdir)
  export PKG_CONFIG_PATH=""
}

autotools_build() {
  # Usage: autotools_build [extra configure args...]
  autotools_env
  (cd "$BUILD_DIR" && "$SRC_DIR/configure" \
      --host="$TARGET_TRIPLE" --build="$(uname -m)-pc-linux-gnu" \
      --prefix="$PREFIX" --libdir="$PREFIX/lib" \
      --enable-static --disable-shared "$@")
  make -C "$BUILD_DIR" -j "$BLA_JOBS"
  make -C "$BUILD_DIR" install
}

write_meson_cross_file() {
  local f=$BLA_WORK/meson-android-arm64.ini
  local cargs="" a
  for a in $BLA_CFLAGS $(dep_cppflags); do cargs+="'$a', "; done
  local largs=""
  for a in $BLA_LDFLAGS $(dep_ldflags); do largs+="'$a', "; done
  mkdir -p "$BLA_WORK"
  cat > "$f" <<EOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$AR'
strip = '$STRIP'
nm = '$NM'
ranlib = '$RANLIB'
pkg-config = 'pkg-config'

[built-in options]
c_args = [${cargs%, }]
cpp_args = [${cargs%, }]
c_link_args = [${largs%, }]
cpp_link_args = [${largs%, }]
default_library = 'static'
b_staticpic = true

[properties]
pkg_config_libdir = '$(dep_pkgconfig_libdir)'
needs_exe_wrapper = true

[host_machine]
system = 'android'
subsystem = 'android'
kernel = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF
  echo "$f"
}

meson_build() {
  # Usage: meson_build [extra meson args...]
  local cross; cross=$(write_meson_cross_file)
  PKG_CONFIG_LIBDIR=$(dep_pkgconfig_libdir) PKG_CONFIG_PATH="" \
  meson setup "$BUILD_DIR" "$SRC_DIR" --cross-file "$cross" \
    --prefix="$PREFIX" --libdir=lib --buildtype=release \
    -Ddefault_library=static "$@"
  ninja -C "$BUILD_DIR" -j "$BLA_JOBS"
  ninja -C "$BUILD_DIR" install
}

# Fail loudly if an installed static library is not AArch64 (catches host leaks).
check_arch() {
  local f bad=0
  while IFS= read -r -d '' f; do
    if ! "$READELF" -h "$f" 2>/dev/null | grep -q 'AArch64'; then
      warn "not an AArch64 object: $f"; bad=1
    fi
  done < <(find "$PREFIX" -name '*.a' -print0 2>/dev/null)
  (( bad == 0 )) || die "$RECIPE_NAME: non-AArch64 objects installed"
}
