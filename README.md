# Android port of Blender (working title: `<MY_APP_NAME>`)

An unofficial Android (arm64-v8a, Android 10+, Vulkan) port of the Blender 3D creation suite.
This project is **not affiliated with or endorsed by the Blender Foundation**. It does not use the
Blender name or logo for the app.

* Upstream base: Blender **v5.3.0** (see [`upstream/blender.lock`](upstream/blender.lock))
* License: **GPL-3.0-or-later** (see [`LICENSE`](LICENSE)). All source changes are published here.
* Approach: keep changes to upstream minimal. Android code lives in new files behind
  `__ANDROID__` / CMake options, and the few edits to upstream files are kept as a small patch
  series so the port can be rebased onto future releases.

## Status

| Phase | Topic | State |
|---|---|---|
| 1 | Analysis: platform layers and dependency classification | ✅ done, see [`docs/phase1-analysis.md`](docs/phase1-analysis.md) |
| 2 | NDK dependency builds + headless build | not started |
| 3 | GHOST Android backend + Vulkan | not started |
| 4 | Touch / stylus / keyboard input, modifier bar, DPI | not started |
| 5 | Scoped storage / SAF, lifecycle, autosave | not started |
| 6 | Feature audit + performance | not started |
| 7 | Gradle packaging + GitHub Actions | not started |
