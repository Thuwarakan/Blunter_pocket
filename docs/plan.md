# Project plan (revised after Phase 1)

## Why the plan changed

Phase 1 analysed the v5.3.0 release tag only. Blender has an **official `android` branch**
(`blender/blender`, active, by core developers). It already provides much of what Phases 2–4
and 7 planned:

| Planned | Official `android` branch (pinned in `upstream/blender.lock`) |
|---|---|
| Dependency cross-compile scripts | Blender's own `build_environment` cross-compiles for Android (Meson cross file, host LLVM/ISPC, Android patches for Python, USD, x265, OIDN...). Results are published as the pre-built `lib/android_arm64` submodule. |
| Cross-compile host tools | `build_files/cmake/host_tools.cmake`: a host sub-build of makesdna/makesrna/datatoc/shader_tool/msgfmt with the same `WITH_*` options. Pre-built `lib/linux_x64` supplies host Python. |
| Windowing / input | SDL3 GHOST backend; `SDLActivity` loads `libblender.so` (`source/creator/creator_android.cc`). |
| Vulkan on Android | Android swapchain fixes (identity pre-transform, SUBOPTIMAL on rotation, resize), `gpu_BaseInstance` removed, an Adreno shader-compiler workaround. |
| APK packaging | `release/android` Gradle skeleton + `gradle_stage` / `gradle_assemble` CMake targets; `make android`. |
| Target | minSdk 29 (Android 10), targetSdk 36, arm64-v8a and x86_64. |

This project therefore builds **on top of** that branch: upstream stays untouched except for
small patches in `patches/blender/`; our additions live in new files.

The from-scratch dependency framework written before this was found is kept in git history
(commit `6daeb4d`) but no longer used. The official branch made the same `BLI_subprocess` fix
it contained.

## Phases

| # | Phase | Status | Scope now |
|---|---|---|---|
| 1 | Analysis | ✅ | `docs/phase1-analysis.md` (+ addendum below) |
| 2 | Build the official branch reproducibly | 🔄 | `scripts/build.sh`, CI workflow `android-apk.yml`, branding overlay; first green APK; pin NDK version |
| 3 | GPU coverage | ⏳ | Upstream still *requires* `geometryShader`, `dualSrcBlend`, `drawIndirectFirstInstance` (`vk_backend.cc`), which excludes Mali and some older drivers. Patch: geometry shaders optional (no shader uses them), dual-source blend fallback, mobile vendor IDs + TBDR flag. Port the Vulkan 1.1 / Mali work from simfeo/blender where it is clean. |
| 4 | Input and UI | ⏳ | Requested touch scheme (1 finger LMB, 2-finger orbit, pinch zoom, 3-finger pan, long-press RMB), stylus pressure/tilt, Bluetooth keyboard/mouse, on-screen modifier bar (Shift/Ctrl/Alt/Tab/Esc/numpad), DPI auto-scale. Via SDL events in GHOST_SystemSDL behind `__ANDROID__`, plus a Java overlay for the modifier bar. |
| 5 | Platform integration | ⏳ | SAF open/save (`content://` → fd bridge), app-private config/add-ons/temp, lifecycle (pause → autosave, surface loss, `onTrimMemory`), first-run extraction progress screen. **Security:** upstream `BlenderActivity` accepts `--python-expr` via an intent extra from any app; restrict it to debuggable builds. |
| 6 | Feature completeness + performance | ⏳ | Per-editor audit (works / degraded / disabled), device testing (Snapdragon 7-series 8 GB, flagship), optimisation. |
| 7 | Packaging and CI | ⏳ | Release signing, AAB, versioning, rename in-app splash/about branding where required, artifact publishing. |
| 8 | **Claude integration** (new) | ⏳ | Both options below. |

## Phase 8: Claude integration

The Claude Android app has no on-device way to reach other apps: it only uses *remote* MCP
connectors, which Anthropic's cloud calls over the public internet. So there are two paths,
and both are planned. They share one set of Blender tools.

**Shared tool layer** (bundled Python add-on, `claude_bridge`):
scene/object inspection, create/transform/delete objects, modifiers and materials,
Geometry Nodes inputs, render (Cycles/EEVEE) and return the image, viewport screenshot,
save. Arbitrary `exec` of Python is **off by default** and needs an explicit per-session
toggle. Every mutating call is undoable, and a visible "Claude connected" indicator has a
kill switch.

**8a – In-app Claude panel** (works entirely inside the app)
- A sidebar chat in the app calls the Claude Messages API with tool use. The tools are the
  layer above, and viewport screenshots are sent as images.
- Needs a Claude API key (console.anthropic.com, billed per use, separate from Claude.ai
  plans). It is stored with Android Keystore-backed encryption, never in `.blend` files or
  preferences exports.
- Default model: the latest Claude model the key has access to (configurable).

**8b – Claude Android app via remote connector** (uses the user's Claude subscription)
- A small relay service exposes a Streamable-HTTP MCP endpoint with OAuth. The user adds it
  once at claude.ai → Settings → Connectors, and it syncs to the Claude Android app.
- The app's add-on opens an **outbound** WebSocket to the relay, so there are no inbound
  ports and it works on mobile data. The relay forwards tool calls to the paired device.
  Pairing uses a one-time code shown in the app.
- Path on the same phone: Claude app → Anthropic cloud → relay → phone.
- Relay: small, stateless, self-hostable (container + `deploy/` docs). It is never given
  the user's files beyond the tool results Claude requests.

**Not available yet:** direct app-to-app on the phone. Android 16 AppFunctions is
experimental and no Claude support is known. We may expose AppFunctions later so that
on-device assistants can call the same tools.
