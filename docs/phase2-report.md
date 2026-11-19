# Phase 2 report – reproducible build of the official `android` branch

Date: 2026-11-18. Upstream: Blender `android` @ `e1cb5848` (5.3 alpha).

## Result

**CI builds a complete, branded arm64 APK from scratch in about 77 minutes.**
Run [#4](https://github.com/Thuwarakan/Blunter_pocket/actions/runs/44391033075),
artifact `android-arm64-apk`.

| Step | Time (cold, `ubuntu-24.04`, 4 vCPU) |
|---|---|
| Fetch upstream, `lib/android_arm64` (1.2 GB) and `lib/linux_x64` via Git LFS, branding | 7.7 min |
| Host code generators + cross-compile `libblender.so` (7,803 Ninja steps) | 66 min |
| Gradle staging + `assembleRelease` | 1.5 min |
| APK size | **307 MB** (debug symbols not stripped, see below) |

Feature set (upstream defaults, configure summary in the CI log):
- Rendering: Cycles CPU with Embree, OSL, path guiding, OpenImageDenoise.
- Formats and data: USD, MaterialX, OpenVDB/NanoVDB, Alembic.
- Media: FFmpeg, OpenAL, sndfile, Rubberband.
- Modelling and simulation: GMP + Manifold booleans, OpenSubdiv, fluid/ocean sim.
- Other: Python 3.13 + NumPy, Vulkan backend, SDL3 GHOST.

## What works (verified)

- `scripts/build.sh all` works end to end on a clean Linux x86-64 machine: fetch, patches, branding, `make android`, then Gradle.
- Branding applied: package `io.github.thuwarakan.blunterpocket`, label "Blunter Pocket", our adaptive icon, Blender logo rasters removed.
  - Read back from the built APK by `aapt2 dump badging` in CI (run #5):
    `package: name='io.github.thuwarakan.blunterpocket' versionCode='105030000' versionName='5.3.0-alpha'`,
    `targetSdkVersion:'36'`, `application-label:'Blunter Pocket'`, `native-code: 'arm64-v8a'`.
  - Run #5's verify step itself failed on a bug in the check: newer `aapt2` prints `minSdkVersion:`, not `sdkVersion:`. Fixed in the following commit.
- Run [#6](https://github.com/Thuwarakan/Blunter_pocket/actions/runs/44416649341): all checks pass.
  - `minSdkVersion:'29'`, `targetSdkVersion:'36'`.
  - **43 native libraries, 465 MB uncompressed**, 3,945 asset entries.
- CI time with a warm ccache:
  - compile 48.5 min on the first warm run, then **3 min** once the cache held the whole build;
  - the whole job takes **14 min**, of which fetching is 8 min.
- NDK pinned to `30.0.16248370`, JDK 21, Gradle 9.4.1 / AGP 9.2.0 (upstream wrapper).

## What is not verified yet

- **Running on a device.** No Android device or emulator is available to this setup.
  - x86-64 emulators can't run this arm64-only build properly.
  - `tests/device/run_smoke.sh <apk>` does the original Phase 2 check over adb: it writes a `.blend`, reopens it, runs Python checks (stdlib, NumPy, OpenSubdiv, both boolean solvers) and does a Cycles render. It has to be run with a phone connected.
- GUI start-up, Vulkan on specific GPUs and touch input are Phase 3–4 topics.

## Failures and fixes (exact errors)

| Run | Error | Cause | Fix |
|---|---|---|---|
| headless #1 | `Fetch Blender` failed | Superseded: the from-scratch pipeline was dropped when the official branch was found | Removed (history: `6daeb4d`) |
| apk #1 | `CMake Error at tests/python/CMakeLists.txt:166: No Python configured for running tests, set TEST_PYTHON_EXE.` | Upstream leaves `PYTHON_EXECUTABLE` empty when cross-compiling | Pass `-DTEST_PYTHON_EXE=$(command -v python3)` through `BUILD_CMAKE_ARGS` (`6532310`). **Upstream bug.** |
| apk #2 | `ninja: error: '…/lib/linux_x64/osl/bin/oslc', needed by '…/node_add_closure.oso', missing` | Log: `Skipping submodule 'lib/linux_x64'`. `.gitmodules` sets `update = none` for `lib/*` | `git -c submodule.lib/<x>.update=checkout submodule update` (`f97ecd5`) |
| apk #2 (latent) | Runner default `ANDROID_NDK_ROOT` = NDK 27.3 | Pre-built libs are built with a newer clang/libc++ | Pin NDK `30.0.16248370` in CI (`f97ecd5`) |
| apk #3 | `CMake Error at CMakeLists.txt:106: The minimum supported version of GCC is 14.0.0, found C compiler: 13.3.0` (host_tools sub-build) | The host sub-build uses the system compiler; Ubuntu 24.04 defaults to GCC 13 | Install `gcc-14`; `build.sh` exports `CC/CXX` = newest GCC ≥ 14 / Clang ≥ 17 (`ff09012`) |
| apk #4 | ✅ | | |

## Known issues and proposed fixes

1. **APK is 307 MB because native libraries are not stripped.** Gradle reports `Unable to strip the following libraries … libblender.so …`.
   - Cause: upstream's Gradle project doesn't set `ndkVersion`/`ndkPath`, so AGP has no `llvm-strip`.
   - Fix (Phase 7): set `android.ndkPath`, or strip during staging. Expect well under half the size.
2. **Release builds are `debuggable` and signed with the debug key** (upstream development setting). That makes them unsuitable for distribution. Phase 7: release signing and non-debuggable builds.
3. **Security, upstream:** `BlenderActivity` is exported and accepts `--python-expr` and similar through the `args` extra from any app. Phase 5: honour `args` only in debuggable builds.
4. `intern/guardedalloc`: `We don't know how to use malloc_usable_size on your platform`. Memory statistics fall back to a slower path. Bionic does have `malloc_usable_size`, so this is a small upstream patch candidate.
5. Upstream bugs to report to the `android` branch maintainers:
   - the `TEST_PYTHON_EXE` problem (#1 above);
   - `lib/*` submodules and `make android` aren't documented together (#2 above);
   - the Gradle NDK path (issue 1 above).

## Next

- Run `tests/device/run_smoke.sh` on a phone; until then this phase is "builds" rather than "runs".
- Phase 3 (GPU coverage) starts once on-device start-up is confirmed.
