# Blunter Pocket — Blender for Android (unofficial)

An unofficial Android app (arm64-v8a, Android 10+, Vulkan) built from Blender's official
`android` development branch, with mobile UX, platform integration and Claude integration on
top. **Not affiliated with or endorsed by the Blender Foundation**; the app does not use the
Blender name or logo. "Blunter Pocket" is a working title, set in `branding/branding.env`.

* License: **GPL-3.0-or-later** ([`LICENSE`](LICENSE)); all source changes are published here.
* Upstream: Blender `android` branch, pinned in [`upstream/blender.lock`](upstream/blender.lock).
* Approach: upstream stays untouched except for small patches in `patches/blender/`; our code
  lives in new files (branding overlay, add-ons, Java/C++ additions).

## Build

```bash
# Needs: Android SDK (ANDROID_HOME), NDK, JDK 17+, cmake, ninja, git-lfs,
# network access to projects.blender.org (pre-built libraries).
scripts/build.sh all        # fetch → libblender.so → APK in build/out/
```

CI: `.github/workflows/android-apk.yml` builds the APK on `ubuntu-24.04` and uploads it.

## Status

See [`docs/plan.md`](docs/plan.md) for the phase plan, including Claude integration
(in-app panel + Claude Android app connector).

| Phase | Topic | State |
|---|---|---|
| 1 | Analysis ([`docs/phase1-analysis.md`](docs/phase1-analysis.md)) | ✅ |
| 2 | Reproducible build of the official branch + branding | 🔄 |
| 3 | GPU coverage (Mali, older drivers) | ⏳ |
| 4 | Touch / stylus / keyboard, modifier bar, DPI | ⏳ |
| 5 | Storage (SAF), lifecycle, autosave, security | ⏳ |
| 6 | Feature audit + performance | ⏳ |
| 7 | Release packaging (signing, AAB) | ⏳ |
| 8 | Claude integration | ⏳ |
