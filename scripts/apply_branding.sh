#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Apply this project's app identity (branding/branding.env + branding/android/res) to an
# upstream Blender checkout's Android Gradle skeleton (release/android). Idempotent.
#
# Usage: scripts/apply_branding.sh <blender-source-dir>
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
src=${1:?usage: apply_branding.sh <blender-source-dir>}
app=$src/release/android/app
# shellcheck source=../branding/branding.env
source "$root/branding/branding.env"

[[ -f "$app/build.gradle" ]] || { echo "not a Blender android checkout: $src" >&2; exit 1; }

# 1. Application id (the install identity). The Java namespace stays org.blender.blender:
#    it is internal and keeping it avoids patching upstream sources.
sed -i -E "s|^(\s*applicationId\s*=\s*)'[^']*'|\1'${APP_ID}'|" "$app/build.gradle"
grep -q "applicationId = '${APP_ID}'" "$app/build.gradle" \
  || { echo "failed to set applicationId (upstream build.gradle changed?)" >&2; exit 1; }

# 2. Visible app name.
sed -i -E "s|(<string name=\"app_name\">)[^<]*(</string>)|\1${APP_NAME}\2|" \
  "$app/src/main/res/values/strings.xml"
grep -q ">${APP_NAME}<" "$app/src/main/res/values/strings.xml" \
  || { echo "failed to set app_name" >&2; exit 1; }

# 3. Launcher icon: our own adaptive icon replaces the Blender logo. minSdk is 29, so the
#    adaptive (anydpi-v26) icon is always used and the raster fallbacks are removed.
cp -r "$root/branding/android/res/." "$app/src/main/res/"
find "$app/src/main/res" -path '*/mipmap-*dpi/*' -name 'ic_launcher*.webp' -delete

echo "branding: \"$APP_NAME\" ($APP_ID) applied to $src"
