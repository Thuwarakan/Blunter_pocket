#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Cross-compile Blender's third-party libraries for Android arm64 with the NDK.
#
#   deps/build_deps.sh                  build every library of the default set
#   deps/build_deps.sh --set headless   build a named set (deps/sets/<name>.txt)
#   deps/build_deps.sh zlib png         build only these (in the given order)
#   deps/build_deps.sh --force zlib     rebuild even if up to date
#   deps/build_deps.sh --list           print the libraries of the set
#
# Each library is described by deps/recipes/<name>.sh, which defines a `build`
# function. Results go to $LIBDIR/<name>. A stamp keyed on the recipe, the shared
# helpers and the pinned upstream version makes re-runs skip finished libraries,
# so an interrupted CI run resumes where it stopped.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

set_name=headless
force=0
list_only=0
libs=()
while (( $# )); do
  case "$1" in
    --set) set_name=$2; shift 2 ;;
    --force) force=1; shift ;;
    --list) list_only=1; shift ;;
    -h|--help) sed -n '3,15p' "$0"; exit 0 ;;
    *) libs+=("$1"); shift ;;
  esac
done

if (( ${#libs[@]} == 0 )); then
  set_file=$BLA_ROOT/deps/sets/$set_name.txt
  [[ -f "$set_file" ]] || die "unknown set $set_name"
  mapfile -t libs < <(sed -e 's/#.*//' -e '/^\s*$/d' "$set_file")
fi

if (( list_only )); then printf '%s\n' "${libs[@]}"; exit 0; fi

setup_toolchain
mkdir -p "$LIBDIR/.stamps" "$BLA_WORK" "$BLA_BUILD/logs"

recipe_stamp() {
  local lib=$1
  {
    cat "$BLA_ROOT/deps/recipes/$lib.sh" "$BLA_ROOT/deps/lib.sh" \
        "$BLA_ROOT/deps/toolchain/android-arm64.cmake"
    echo "$NDK_REVISION $ANDROID_API"
    # Version pins of the libraries this recipe downloads.
    grep -o 'unpack [A-Z0-9_]*' "$BLA_ROOT/deps/recipes/$lib.sh" | while read -r _ dep; do
      dep_info "$dep" && echo "$dep $DEP_VERSION $DEP_HASH"
    done
    # Any of our own patches the recipe uses.
    grep -o 'apply_android_patch [^ ]*' "$BLA_ROOT/deps/recipes/$lib.sh" | while read -r _ p; do
      cat "$BLA_ROOT/deps/patches/$p"
    done
  } | sha256sum | cut -d' ' -f1
}

built=() skipped=()
for lib in "${libs[@]}"; do
  recipe=$BLA_ROOT/deps/recipes/$lib.sh
  [[ -f "$recipe" ]] || die "no recipe for $lib ($recipe)"
  stamp_file=$LIBDIR/.stamps/$lib
  stamp=$(recipe_stamp "$lib")
  if (( ! force )) && [[ -f "$stamp_file" && "$(cat "$stamp_file")" == "$stamp" ]]; then
    skipped+=("$lib"); continue
  fi

  log "==== building $lib ===="
  start=$(date +%s)
  logfile=$BLA_BUILD/logs/$lib.log
  # NOTE: the subshell must not be the left side of `||`, bash would then silently
  # disable `set -e` inside it.
  set +e
  (
    set -euo pipefail
    RECIPE_NAME=$lib
    PREFIX=$LIBDIR/$lib
    rm -rf "${PREFIX:?}"
    # shellcheck source=/dev/null
    source "$recipe"
    build
    check_arch
  ) > >(tee "$logfile") 2>&1
  rc=$?
  set -e
  if (( rc != 0 )); then
    sleep 1   # let tee flush
    echo "::error::$lib failed (exit $rc), see $logfile" >&2
    exit 1
  fi
  echo "$stamp" > "$stamp_file"
  rm -rf "${BLA_WORK:?}/${lib:?}"     # keep CI disk usage low
  log "==== $lib done in $(( $(date +%s) - start ))s ===="
  built+=("$lib")
done

log "built: ${built[*]:-none}"
log "up to date: ${skipped[*]:-none}"
