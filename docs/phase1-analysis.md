# Phase 1 – Platform & Dependency Analysis

Upstream analysed: **Blender v5.3.0** (`02f0899d78e3`, tag date 2026-11-09), the latest
stable tag on `github.com/blender/blender` at the time of writing (see `upstream/blender.lock`).

Target: `arm64-v8a`, `minSdkVersion 29` (Android 10), Vulkan, NDK r27+ (clang 18+, libc++).

All file references below are relative to the Blender source root.

---

## 0. Summary

| Area | Verdict |
|---|---|
| Overall feasibility | **Feasible.** Blender already ships official **Linux aarch64** builds, so the NEON / `sse2neon` code paths, Embree-ARM, OIDN-ARM and the Cycles CPU kernel on ARM all exist upstream. Most Android work is in windowing/input, packaging and the GPU feature gaps of mobile drivers. |
| Hard blocker #1: GPU | Blender's Vulkan backend **refuses to start** on GPUs without `geometryShader`, `dualSrcBlend`, `drawIndirectFirstInstance`, `imageCubeArray`, or without `VK_KHR_dynamic_rendering`, `VK_KHR_timeline_semaphore`, `VK_KHR_buffer_device_address`, `VK_KHR_separate_depth_stencil_layouts` (`source/blender/gpu/vulkan/vk_backend.cc:144-199`). **Every Mali GPU lacks `geometryShader`.** But no Blender shader uses a geometry stage anymore, so that check can be relaxed with a small patch. Other gaps have to be checked on real devices (§3.3). |
| Hard blocker #2: Cross-compiling | Blender builds code generators (`makesdna`, `makesrna`, `datatoc`, `shader_tool`, `msgfmt`) and **runs them during the build** via `$<TARGET_FILE:…>`. Upstream has no cross-compile support for this, so a host-tools stage and a small CMake patch are needed (§2.6). |
| Device floor | The APK can install on Android 10. In practice the **GUI needs a Vulkan 1.3-class driver** (dynamic rendering, timeline semaphores, BDA). That usually means a 2022+ SoC on Android 13+ firmware. Older devices can still run the **headless** build. |
| No OpenGL fallback | Blender's GL backend needs desktop GL 4.3 core (not GLES), so it cannot serve as a fallback on Android. |
| Not portable at all | CUDA, OptiX, HIP, HIP-RT, oneAPI/SYCL, Metal (Cycles devices); OpenXR (for phones); NDOF/spacenav; X11/Wayland/DBus. |

---

## 1. Platform-dependent layers

### 1.1 GHOST (windowing / input / system paths) — `intern/ghost/`

| Piece | Upstream implementations | Android plan |
|---|---|---|
| `GHOST_ISystem::createSystem` (`intern/GHOST_ISystem.cc:57-241`) | Chosen at **compile time** by `#if` chain: `WITH_HEADLESS` → X11/Wayland → `WITH_GHOST_SDL` → Win32 → Cocoa. | Add an `#elif defined(__ANDROID__)` branch creating `GHOST_SystemAndroid` (≈6 lines upstream). |
| System + window | `GHOST_System{X11,Wayland,Win32,Cocoa,SDL,Headless}`, matching `GHOST_Window*` | **New** `GHOST_SystemAndroid` / `GHOST_WindowAndroid` (single full-screen window; Blender's "child windows" become fullscreen overlays or are disallowed). |
| Vulkan context | `GHOST_ContextVK.cc`. Surface creation has per-platform `#if` blocks (`:897-924`, `:1736-1790`, `:1864-1915`). Win32, Metal, Xlib, Wayland, and SDL (`SDL_Vulkan_CreateSurface`). | Add an `ANativeWindow*` member, `VK_KHR_android_surface`, and `vkCreateAndroidSurfaceKHR`. ≈4 small `#ifdef __ANDROID__` blocks in upstream. |
| GL contexts | GLX, EGL, WGL, CGL, SDL | Not used (`WITH_OPENGL_BACKEND=OFF`). |
| System paths | `GHOST_SystemPathsUnix.cc` uses `$HOME`, `$XDG_CONFIG_HOME`, `$XDG_CACHE_HOME`, `getpwuid` | **No upstream change.** The launcher sets `HOME`, `XDG_*` and the `BLENDER_*` overrides (§1.5) to app-private dirs before calling Blender's `main`. |
| NDOF, IME, DnD, CSD, D-Bus | Unix/Win/mac only | NDOF off. Soft keyboard / IME through `GameActivity`'s text input → `GHOST_kEventKeyDown` with UTF-8. DnD → Android "share/open with" intents (Phase 5). |
| **Shortcut found:** `GHOST_SystemSDL` (SDL3) | Already creates a Vulkan surface through SDL (`WITH_GHOST_SDL`). SDL3 supports Android (its `SDLActivity` Java glue, touch, pen pressure, IME, lifecycle events). | Optional **bootstrap path for Phase 3**: get pixels on screen with zero new GHOST code, then replace it with the native backend. Upstream marks the SDL GHOST as limited (no multi-window, partial input), so it is not the end state. |

### 1.2 GPU module — `source/blender/gpu/`

* Backends: `opengl/` (42 files, desktop GL 4.3), `vulkan/` (97 files), `metal/` (54 files), `dummy/`.
  For Android: **Vulkan only** (`WITH_VULKAN_BACKEND=ON`, `WITH_OPENGL_BACKEND=OFF`; `WITH_METAL_BACKEND` is forced OFF off-Apple).
* Runtime dependencies of the Vulkan backend: **volk** (`extern/volk`, loads `libvulkan.so` dynamically, which is good on Android), **VMA** (`extern/vulkan_memory_allocator`), **shaderc** (GLSL→SPIR-V on the device at runtime), Vulkan headers.
  Android supplies the loader (`/system/lib64/libvulkan.so`), so the Khronos loader is **not** built.
* Platform/vendor detection: `vk_device.cc:380-420` maps driver IDs for AMD/NVIDIA/Intel/Qualcomm/Apple/Mesa only.
  `VK_DRIVER_ID_ARM_PROPRIETARY` (Mali), `IMAGINATION_PROPRIETARY` (PowerVR) and `SAMSUNG_PROPRIETARY` (Xclipse) all fall into `GPU_DEVICE_UNKNOWN`.
  `GPU_OS_*` has no Android value. The Vulkan backend always reports `GPU_ARCHITECTURE_IMR` (`vk_backend.cc:478`); `GPU_ARCHITECTURE_TBDR` exists but only Metal uses it.
* Existing Qualcomm workarounds (written for Windows-on-ARM Snapdragon X) are a useful start: viewport-state reset bug, local-read enabled, vertex-input-dynamic-state off (Win only). The minimum driver version check (`:122-138`) is Win32-only.
* Build-time GLSL processing (`shader_tool`, `datatoc`) is a host tool. See §2.6.

### 1.3 Python embedding — `source/blender/python/`

* `bpy_interface.cc:510-570` initialises CPython 3.13 via `PyConfig`.
  `config.home` comes from `BKE_appdir_folder_id(BLENDER_SYSTEM_PYTHON)` (`<resources>/python`), which can be overridden with `$BLENDER_SYSTEM_PYTHON`.
* CPython **3.13 officially supports Android** (PEP 738, tier-3; `Android/android.py` in the CPython tree).
  We cross-build with `--host=aarch64-linux-android --with-build-python=python3.13`, link libpython statically like Blender does on Linux, and ship the stdlib in the APK, extracted on first run.
* Modules affected on Android: `multiprocessing` synchronisation primitives (bionic has no `sem_open`); `subprocess` works but there is no useful `/bin` userland; `ctypes` needs libffi (built); `ssl` needs OpenSSL (built) plus a CA bundle (`certifi`, already shipped by Blender).
* Add-ons and extensions are pure Python and work as-is. Extensions with **native wheels** need `android_arm64` wheels, which are rarely available. That limitation goes in the docs.

### 1.4 Threading — `source/blender/blenlib/intern/threads.cc`, TBB

* Blender uses pthreads + TBB (`WITH_TBB` is mandatory in practice).
  oneTBB 2022.x supports Android officially.
* **`WITH_TBB_MALLOC_PROXY` must be OFF.** The proxy overrides libc `malloc` symbols, which is not safe on bionic. `creator.cc:398` also turns on TBB huge pages under `__linux__`; on Android that becomes a harmless no-op.
* `BLI_system_thread_count()` uses `sysconf(_SC_NPROCESSORS_ONLN)` and returns every core, including LITTLE cores. Scheduling on big.LITTLE gets tuned in Phase 6.
* Cycles `util/thread.cpp` already sets 2 MB pthread stacks for non-glibc Linux (`__linux__ && !__GLIBC__` is true on bionic), which is what we want.

### 1.5 File paths and the filesystem — `blenkernel/intern/appdir.cc`, `blenlib`

* Program location: `where_am_i()` (`appdir.cc:905`) uses `argv[0]`.
  On Android the process is `app_process64` and Blender is a `.so`, so the launcher passes a fake `argv[0]` that points inside the extracted resources dir.
* **Every resource root can be overridden through environment variables**, so path handling needs **no upstream changes**:
  `BLENDER_SYSTEM_RESOURCES`, `BLENDER_USER_RESOURCES`, `BLENDER_{USER,SYSTEM}_{DATAFILES,SCRIPTS,EXTENSIONS}`, `BLENDER_USER_CONFIG`, `BLENDER_SYSTEM_PYTHON` (`appdir.cc:506-805`).
* Scoped storage: Blender reads files through POSIX `open()`. SAF `content://` URIs need either a file-descriptor bridge (`/proc/self/fd/N`) or copy-in/copy-out into the app sandbox. This is designed in Phase 5. `MANAGE_EXTERNAL_STORAGE` is an optional power-user path (not allowed for most Play Store apps).
* `fsmenu_system_unix.cc` (file browser bookmarks) reads `/etc/mtab` and XDG user dirs. Android adds its own bookmarks for app storage, Downloads and SAF-granted folders (new Android-only file).

### 1.6 Other OS-specific code that bionic/NDK affects

Bionic defines `__linux__`, so every `__linux__` branch is compiled. I audited them:

| Location | Issue | Action |
|---|---|---|
| `blenlib/BLI_subprocess.hh:18` | `BLI_SUBPROCESS_SUPPORT=1` on `__linux__` → uses **`shm_open`** (not in bionic), `fork`, `/proc/self/exe` (used for parallel shader-compile subprocesses). | **Patch:** `&& !defined(__ANDROID__)` (one line). |
| `blenlib/intern/system.cc:28` | `execinfo.h` backtrace | Already guarded by `HAVE_EXECINFO_H`. bionic has it only from API 33, and the CMake check handles that. Optionally add an `<unwind.h>` backtrace for crash logs (new file). |
| `creator/creator_signals.cc:273` | `feenableexcept` | Guarded by `HAVE_FEENABLEEXCEPT`, only in debug FPE mode. OK. |
| `intern/libc_compat/libc_compat.c` | glibc `__*_finite` shims | Guarded by `__GLIBC_PREREQ`, so it is a no-op on bionic. OK. |
| `blenlib/intern/storage.cc:30` | `<sys/vfs.h>`, `getpwuid` | Both exist in bionic. OK. |
| `intern/guardedalloc` | `malloc_stats`, `execinfo` | Debug-only paths. OK. |
| `build_files/cmake/platform/platform_unix.cmake` | Looks for `lib/linux_{arm64,x64}` and needs `Epoxy`, X11/Wayland detection, `Python` via `PythonLibsUnix` | New `platform_android.cmake` (Android-only file) plus a one-line `elseif(ANDROID)` include in the root `CMakeLists.txt`. |
| C++20 / libc++ | Scanned for `std::execution`, `<memory_resource>`, `std::jthread`, `<stacktrace>`, `std::format`, floating-point `from_chars`: none are used (`std::format` is explicitly avoided). | OK with NDK r27 libc++. |

### 1.7 Audio, video, misc

* **Audio** (Audaspace, `extern/audaspace`): backends are OpenAL, SDL, JACK, PulseAudio, PipeWire, CoreAudio, WASAPI.
  Android uses **OpenAL-Soft**, which has OpenSL ES / Oboe(AAudio) backends. An AAudio Audaspace plugin can come later.
* **Video**: FFmpeg cross-builds for Android (`--target-os=android`). Hardware MediaCodec encoding is a later option.
* **Host-side GPU tools** (RenderDoc dynload, Tracy): off.

---

## 2. Third-party libraries (`build_files/build_environment`)

Legend:
**✅ As-is**: cross-compiles with the NDK CMake toolchain / `--host=aarch64-linux-android` and the flags Blender already uses for Linux-arm64.
**🔧 Patch**: needs build-script changes or small source patches.
**⏸ Defer**: portable in principle but heavy. Disabled for the first APK and revisited in Phase 6.
**❌ Disable**: cannot exist on, or makes no sense on, Android.
**🛠 Host**: build-machine tool only, not shipped.

"Phase" = when it gets built. **H** = headless MVP (Phase 2), **G** = GUI (Phase 3+), **L** = later.

### 2.1 Core / imaging / geometry

| Library | Ver | Build | Class | Ph | Notes |
|---|---|---|---|---|---|
| zlib | 1.3.1 | cmake | ✅ | H | Built statically, not taken from the NDK, so it matches desktop. |
| zstd | 1.5.7 | cmake | ✅ | H | Required (`.blend` compression). |
| deflate | 1.18 | cmake | ✅ | H | OpenEXR. |
| brotli | 1.0.10 | cmake | ✅ | H | FreeType WOFF2. |
| bzip2 | 1.0.8 | make | ✅ | H | Python `bz2`. |
| lzma (xz) | 5.2.5 | autotools | ✅ | H | Python `lzma`. |
| png | 1.6.58 | cmake | ✅ | H | NEON on. |
| jpeg (libjpeg-turbo) | 2.1.3 | cmake | ✅ | H | Upstream supports Android, NEON SIMD. |
| tiff | 4.7.1 | cmake | ✅ | H | |
| webp | 1.6.0 | cmake | ✅ | H | NEON; `cpufeatures` not needed on arm64. |
| openjpeg | 2.5.3 | cmake | ✅ | H | |
| openjph | 0.25.2 | cmake | ✅ | H | Its SIMD kernels are x86-only; on ARM the generic C++ path is used automatically. |
| imath | 3.2.2 | cmake | ✅ | H | |
| openexr | 3.4.10 | cmake | ✅ | H | Apply Blender's 3 openexr patches. |
| libheif | 1.20.2 | cmake | ✅ | H | Only with aom (no x265 decode needed). |
| freetype | 2.13.3 | cmake | ✅ | H | |
| harfbuzz | 10.0.1 | meson | ✅ | G | Meson cross-file; glib/icu/cairo off. |
| fribidi | 1.0.12 | meson | ✅ | G | |
| thorvg | 1.0.3 | meson | ✅ | H | SVG icons; needed even headless (icon data). |
| expat | 2.7.5 | cmake | ✅ | H | |
| pugixml | 1.10 | cmake | ✅ | H | |
| xml2 | 2.14.6 | cmake | ✅ | H | Python bindings off; `iconv` comes from bionic (API ≥ 28). |
| yaml-cpp | 0.8.0 | cmake | ✅ | H | OCIO. |
| pystring | 1.1.3 | cmake | ✅ | H | OCIO (Blender's own CMakeLists). |
| minizip-ng | 4.2.2 | cmake | ✅ | H | OCIO; OpenSSL/lzma off. |
| fmt | 12.1.0 | cmake | ✅ | H | |
| robin-map | 1.3.0 | header | ✅ | H | |
| rapidjson | git | header | ✅ | L | OTIO. |
| sse2neon | git | header | ✅ | H | **Required** on ARM (Blender includes it whenever `BLENDER_PLATFORM_ARM`). |
| Eigen | git | header | ✅ | H | |
| abseil | 20250814.1 | cmake | ✅ | H | Ceres dependency. |
| ceres | git | cmake | ✅ | H | libmv (motion tracking). |
| potrace | 1.16 | cmake | ✅ | H | Grease Pencil trace. |
| haru (libharu) | 2.4.5 | cmake | ✅ | H | GP PDF export. |
| gmp (+gmpxx) | 6.3.0 | autotools | 🔧 | H | `--host=aarch64-linux-android`; aarch64 asm works with clang. Blender's `gmp.diff` and gmpxx CMakeLists. If the asm misbehaves, fall back to `--disable-assembly`. |
| manifold | 3.5.2 | cmake | ✅ | H | Fast boolean. Make sure FetchContent is offline (pass Clipper2 / TBB explicitly). |
| fftw3 | 3.3.10 | autotools | ✅ | H | Double and float builds; `--enable-neon` on the float build. |
| opensubdiv | 3.7.0 | cmake | ✅ | H | CPU + TBB only. GL/CUDA/OpenCL/Metal/examples off. Blender's GPU evaluation goes through its own GPU module. |
| draco | 1.5.7 | cmake | ✅ | L | glTF add-on. |
| meshoptimizer | 1.1 | cmake | ✅ | L | glTF add-on. |
| ktx | 4.4.2 | cmake | 🔧 | L | glTF; tools/tests off; check that ASTC-encoder SIMD detection picks NEON. |
| jolt | 5.6.0 | cmake | ✅ | G | Supports Android upstream. |
| alembic | 1.8.3 | cmake | ✅ | G | |
| opentimelineio | git | cmake | 🔧 | L | Blender patches; Python bindings off. |

### 2.2 Colour, image I/O, volumes

| Library | Ver | Build | Class | Ph | Notes |
|---|---|---|---|---|---|
| OpenColorIO | 2.5.0 | cmake | 🔧 | H | Apps, Python, tests and GPU tests off. SIMD through `sse2neon`, as on Linux-arm64. **Required** (colour management is not optional). |
| OpenImageIO | 3.1.16 | cmake | 🔧 | H | Tools, Python, Qt, OpenCV, DICOM, Ptex, libraw off. Apply Blender's 3 patches. Expect small `Sysutil` patches (memory/cpu queries). **Required.** |
| blosc | 1.21.1 | cmake | ✅ | H | `DEACTIVATE_SSE2/AVX2=ON` on ARM (as Linux-arm64). |
| OpenVDB / NanoVDB | 13.0.0 | cmake | 🔧 | G | TBB + Blosc. Blender's `openvdb.diff`. Large compile and memory footprint. Volumes and Geometry Nodes volume features depend on it. |

### 2.3 Python stack

| Library | Ver | Build | Class | Ph | Notes |
|---|---|---|---|---|---|
| Python | 3.13.13 | autotools | 🔧 | H | Cross build (PEP 738 support upstream). Static `libpython3.13.a`, `--with-build-python`, `ac_cv_*` overrides for cross. Needs ffi, ssl, sqlite, bz2, lzma, zlib from this list. **Not** Blender's `python.cmake` desktop path. |
| libffi | 3.5.2 | autotools | ✅ | H | `ctypes`. |
| OpenSSL | 3.5.6 | perl Configure | 🔧 | H | `./Configure android-arm64` (upstream target), `no-shared`. `ANDROID_NDK_ROOT` env. |
| SQLite | 3.51.3 | autotools | ✅ | H | |
| NumPy | 2.3.4 | meson-python | 🔧 | H | Meson cross file, `-Dallow-noblas=true` (lapack-lite). Known to work (BeeWare/Chaquopy ship Android NumPy). Many add-ons and Audaspace use it. |
| Cython | 3.0.11 | pip | 🛠 | H | Host-only, for building NumPy. |
| meson / meson-python / setuptools* / packaging / pyproject-metadata / tomli-w | – | pip | 🛠 | H | Host build helpers. |
| zstandard (py) | 0.25.0 | setuptools | 🔧 | H | C extension; cross-compile with `_PYTHON_HOST_PLATFORM` / crossenv. |
| requests, urllib3, idna, charset-normalizer, certifi, cattrs, attrs, typing-extensions, autopep8, pycodestyle, docutils | – | pip | ✅ | H | Pure Python (use the pure-Python charset-normalizer wheel). Installed into the shipped site-packages. |
| pybind11 / nanobind | 3.0.1 / 2.1.0 | header(+small lib) | ✅ | L | Only for OCIO/OIIO/USD Python bindings, which are off for now. |

### 2.4 Rendering (Cycles)

| Library | Ver | Build | Class | Ph | Notes |
|---|---|---|---|---|---|
| oneTBB | 2022.3.0 | cmake | 🔧 | H | Upstream Android support. **tbbmalloc_proxy off.** Avoid `TBB_STRICT` warnings-as-errors with clang 18. |
| Embree | 4.4.1 | cmake | 🔧 | H | ARM64 (NEON) supported upstream. SYCL/ISPC/tutorials off. Blender's `embree.diff`. Probable patch: `pthread_setaffinity_np` is **not in bionic**, so use `sched_setaffinity` in `common/sys/thread.cpp`. |
| OpenImageDenoise | 2.5.0 | cmake | 🔧 | G | CPU device on ARM64 is supported (Blender already builds it for Linux-arm64 with `armv8.2-a+dotprod+fp16`). Needs an **ISPC host binary with `--target-os=android`**. GPU devices off. Heavy compile. |
| ISPC | 1.30.0 | cmake | 🛠 | G | Use the **prebuilt Linux x86-64 release** instead of Blender's from-source build (that needs LLVM). ISPC supports `--target-os=android --arch=aarch64`. |
| OpenPGL | 0.7.1 | cmake | 🔧 | G | Path guiding; ARM64 supported. Expect a small CMake arch-detection patch for Android. |
| LLVM | 22.1.7 | cmake | ⏸ | L | Only needed for OSL (JIT) here. Cross-builds for Android but costs about 1 h CI and ~1 GB. |
| OSL | 1.15.6 | cmake | ⏸ | L | `WITH_CYCLES_OSL=OFF` at first. Needs LLVM + Clang libs on device. Android allows anonymous JIT memory (W^X applies to files), so it is feasible later. Needs flex/bison (🛠). |
| flex / bison | 2.6.4 / 2.5.24 | autotools | 🛠 | L | OSL build only. |

### 2.5 Audio / video / codecs

| Library | Ver | Build | Class | Ph | Notes |
|---|---|---|---|---|---|
| OpenAL-Soft | 1.23.1 | cmake | ✅ | G | `ALSOFT_BACKEND_OPENSL=ON` (Oboe optional); utils/examples off. |
| libsndfile | 1.2.2 | cmake | ✅ | G | |
| FLAC / Ogg / Vorbis / Opus | – | cmake | ✅ | G | |
| LAME | 3.100 | autotools | ✅ | G | Blender's `lame.diff`. |
| Theora | 1.1.1 | Blender CMake | ✅ | G | Uses Blender's own CMakeLists. |
| libvpx | 1.15.2 | configure | ✅ | G | `--target=arm64-android-gcc` (works with clang via `CC`/`CXX`). |
| x264 | git | configure | ✅ | G | `--host=aarch64-linux-android --cross-prefix`. |
| x265 | 4.1 | cmake | 🔧 | G | aarch64 asm with clang needs `-DCROSS_COMPILE_ARM64=ON`; if that fails, build with `ENABLE_ASSEMBLY=OFF`. |
| aom | 3.13.1 | cmake | ✅ | G | `AOM_TARGET_CPU=arm64`, runtime CPU detect (Android supported). |
| FFmpeg | 8.1 | configure | 🔧 | G | `--target-os=android --arch=aarch64 --enable-cross-compile`. nvenc/amf/vaapi/vdpau off. Blender's `ffmpeg.diff`. Video Sequencer and movie I/O need it. |
| rubberband | 4.0.0 | meson | ✅ | G | VSE pitch/time stretch. |
| ffnvcodec | 12.1 | – | ❌ | – | NVIDIA only. |
| AMF | 1.5.2 | – | ❌ | – | AMD Windows only. |
| SDL3 | 3.4.2 | cmake | 🔧 | G (opt) | Only if the Phase 3 SDL bootstrap path is used. Needs SDL's Java `SDLActivity`. Otherwise not built. |

### 2.6 GPU / shader toolchain

| Library | Ver | Build | Class | Ph | Notes |
|---|---|---|---|---|---|
| Vulkan-Headers | 1.4.341 | header | ✅ | G | Headers only. |
| Vulkan-Loader | 1.4.341 | – | ❌ | – | **Do not ship.** Android has a system loader; `volk` loads it dynamically. Point `FindVulkan` at the NDK sysroot `libvulkan.so` or volk-only. |
| Vulkan-Utility-Libraries | 1.4.341 | cmake | ✅ | G | Headers/static. |
| shaderc (+glslang, SPIRV-Tools, SPIRV-Headers) | 2025.4 | cmake | ✅ | G | Needed **at runtime**: Blender compiles GLSL to SPIR-V on the device. The NDK also ships a shaderc source tree; build Blender's pinned version for consistency. |
| SPIRV-Reflect | 1.4.341 | cmake | ✅ | G | |
| Vulkan Memory Allocator | 3.2.1 | header | ✅ | G | Also vendored in `extern/`. |
| libepoxy | 1.5.10 | meson | 🔧 | H | `platform_unix.cmake` **requires** Epoxy even without the GL backend. Either cross-build it (`-Dglx=no -Dx11=false -Degl=yes`; upstream supports Android) or skip the `find_package` in `platform_android.cmake`. Prefer skipping it if nothing links it with `WITH_OPENGL_BACKEND=OFF`; to be confirmed in Phase 2. |
| MaterialX | 1.39.4 | cmake | ⏸ | L | Tied to USD/Hydra material export. Builds on mobile (upstream supports iOS). |
| USD | 26.08 | cmake (+python) | ⏸ | L | Huge; Pixar does not support Android. Blender patches remove Boost. Hydra/Storm needs its own GPU backend. `WITH_USD=OFF`, `WITH_HYDRA=OFF` for the first APK. USD import/export is a high-value Phase 6 item. |
| OpenXR SDK | 1.1.53 | cmake | ❌ | – | `WITH_XR_OPENXR=OFF`. Phones have no OpenXR runtime. A Quest/Android-XR build is a separate future project. |
| Tracy | git | cmake | ❌ | – | Profiling only. |

### 2.7 Vendor GPU-compute and desktop-only

| Library | Class | Reason |
|---|---|---|
| HIP-RT, HIP (AMD) | ❌ | No ROCm on Android. |
| DPC++ / SYCL, dpcpp_deps, level-zero, IGC, gmmlib, ocloc, VC-intrinsics, OpenCL ICD, UMF, hwloc, emhash, parallel-hashmap | ❌ | Intel oneAPI GPU stack. |
| CUDA / OptiX (not in deps, SDK-based) | ❌ | No NVIDIA on Android. |
| pthreads-win32 | ❌ | Windows only (bionic has pthreads). |
| wayland, wayland-protocols, weston | ❌ | Linux desktop windowing. |
| spnav (libspnav) | ❌ | 3D mouse daemon. `WITH_INPUT_NDOF=OFF`. |
| NASM | 🛠/❌ | x86 assembler, not needed for arm64. |
| msys2 setup | ❌ | Windows build host only. |

### 2.8 In-tree libraries (`intern/`, `extern/`)

| Library | Class | Notes |
|---|---|---|
| Cycles (CPU) | 🔧 | ARM64 NEON kernel exists. Device backends CUDA/OptiX/HIP/HIP-RT/oneAPI/Metal off. |
| Mantaflow (fluids) | ✅ | Portable C++ + TBB. Fluid sims are slow on phones but work. |
| Bullet, Jolt (rigid body) | ✅ | |
| libmv + glog/gflags (extern) | ✅ | glog has Android support. |
| Audaspace | ✅ | Use the OpenAL plugin. JACK/Pulse/PipeWire off. |
| QuadriFlow, Dualcon, iTaSC, IK, SLIM, mikktspace, curve_fit, rangetree, ufbx, tinygltf, nanosvg, md4c, toml11, xxhash, fast_float, wcwidth | ✅ | Pure C/C++. |
| volk, VMA | ✅ | |
| wayland_dynload, dbus_dynload, renderdoc_dynload, wintab, xdnd, cuew, hipew, glew-es | ❌ | Off via options. |
| binreloc | ❌ | Linux-glibc helper; `WITH_BINRELOC` off. |

**Count** (rows in the §2 tables, in-tree libraries included; some rows group several libraries, e.g. the Intel oneAPI row covers 12): **66 as-is, 19 need patches/build work, 4 deferred (LLVM, OSL, USD, MaterialX), 15 disabled, 4 host-only.** The libraries that need patches are concentrated where the work is anyway: Python, NumPy, OpenSSL, TBB, Embree, OIIO, OCIO, OpenVDB, OIDN, FFmpeg, x265, GMP.

---

## 3. Cross-cutting risks and how we handle them

### 3.1 Host tools when cross-compiling (blocker for Phase 2)

These targets are built **for the target** and then **executed during the build**:

| Tool | Invoked from |
|---|---|
| `makesdna` | `source/blender/makesdna/intern/CMakeLists.txt:109` |
| `makesrna` | `source/blender/makesrna/intern/CMakeLists.txt:429` |
| `datatoc` | `build_files/cmake/macros.cmake:1111,1135,1179` |
| `shader_tool` | `build_files/cmake/macros.cmake:1173` |
| `msgfmt` | `build_files/cmake/macros.cmake:1212` |

Plan:
1. **Host stage.** Configure Blender natively on the CI host with the **same `WITH_*` feature set** (generated RNA code contains `#ifdef WITH_*`). Build only these five targets.
   `makesdna` assumes LP64 with the same alignment rules; x86-64 Linux and aarch64 Android match, and `dna_verify.cc` checks this at compile time on the target.
2. **Android stage.** Add a small patch (≈25 lines across the 5 files above). When `BLENDER_HOST_TOOLS_DIR` is set, those targets become `add_executable(<tool> IMPORTED)` pointing at the host binaries, so the `$<TARGET_FILE:…>` expressions resolve to host executables.
   The patch is self-contained and could be upstreamed.
3. Risk: the host configure must not auto-disable features because libraries are missing. Fix: build `makesrna` with explicit `-DWITH_*` definitions taken from the Android configure (exported cache), not from `find_package` results.

### 3.2 Process model

* Blender's `main()` (`source/creator/creator.cc:332`) runs `WM_main()`, which never returns, and calls `exit()` on quit.
* Plan: build `blender` as `libblender.so`. Rename `main` with `-Dmain=blender_main` on `creator.cc` only, from CMake; no source edit.
  Run it on GameActivity's native thread with a synthesised `argv`.
  A **headless executable** is also built for Phase 2 (`adb push` to `/data/local/tmp`, `blender -b file.blend --python script.py`), which needs no Java at all.
* `exit()` on quit is acceptable on Android (the activity is finished first through JNI).

### 3.3 Vulkan on mobile GPUs: what Blender requires vs. what devices report

Hard requirements (`vk_backend.cc:144-199`) and the current understanding per GPU family.
**Entries marked "verify" have to be confirmed on hardware with `vulkaninfo` / gpuinfo.org in Phase 3. I have not tested on devices.**

| Requirement | Adreno 6xx (SD 7-series '21–'22, 8 Gen 1) | Adreno 7xx/8xx (SD 7+ Gen 2+, 8 Gen 2+) | Mali Valhall/5th-gen (G710+, Immortalis) | Xclipse (Exynos, RDNA) | Blender actually needs it? |
|---|---|---|---|---|---|
| `geometryShader` | yes | yes | **no (all Mali)** | yes | **No.** No `ShaderCreateInfo` calls `geometry_source()` anymore (grep, v5.3.0). The check is vestigial, so we relax it. |
| `dualSrcBlend` | yes | yes | verify | yes | Only for `GPU_BLEND_CUSTOM`: Workbench DoF resolve, Grease Pencil AA, EEVEE shadow/light *debug*. GP AA matters; needs an alternate blend path if missing. |
| `imageCubeArray` | yes | yes | yes | yes | Yes (EEVEE light probes). |
| `drawIndirectFirstInstance` | verify (driver) | yes | verify | yes | Yes: the draw manager encodes resource IDs through `firstInstance`. If missing, pass the base instance through a push constant (non-trivial patch). |
| `fragmentStoresAndAtomics` | yes | yes | yes | yes | Yes (EEVEE, overlays). |
| `VK_KHR_dynamic_rendering` | **often missing on Android 10–12 firmware** | yes | yes (r38+ drivers) | yes | Yes (core of the backend). |
| `VK_KHR_timeline_semaphore` | driver-dependent | yes | yes | yes | Yes (resource lifetime). |
| `VK_KHR_buffer_device_address` | driver-dependent | yes | yes | yes | Yes. |
| `VK_KHR_separate_depth_stencil_layouts` | driver-dependent | yes | yes | yes | Yes. |
| `vertexPipelineStoresAndAtomics` | yes | yes | often no | yes | Debug drawing only (`draw_debug.cc`). Fine. |

Planned GPU workarounds for Phase 3 (all behind `#ifdef __ANDROID__` or driver-ID checks):
1. Make `geometryShader` optional (report it in `GCaps.geometry_shader_support` instead of failing). This unblocks every Mali device if the rest is present.
2. Map `VK_DRIVER_ID_ARM_PROPRIETARY` / `SAMSUNG` / `IMAGINATION` to vendor IDs and set `GPU_ARCHITECTURE_TBDR` for mobile drivers, so Metal-style TBDR paths (load/store ops, local read) are used.
3. Swapchain: Android often supports only `VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR`; Blender hardcodes OPAQUE / PRE_MULTIPLIED (`GHOST_ContextVK.cc:1630`). Also `preTransform = currentTransform` (`:1623`) without rotating content gives a rotated image in landscape on many devices. Use `IDENTITY` (compositor rotates) first, and add pre-rotation as an optimisation.
4. Shader compile cost: hundreds of GLSL shaders compile on the device through shaderc at first launch. Use Blender's on-disk shader/pipeline cache in the app cache dir, and consider shipping a pre-built SPIR-V cache in the APK.
5. Memory: unified memory with tight per-app limits. Lower default texture limits and EEVEE shadow pool size, and handle `onTrimMemory`.
6. Optional for old Adreno 6xx without Vulkan 1.3 drivers: load **Mesa Turnip** through `libadrenotools`, as Android emulators do. Opt-in only.
7. Without the minimum: offer **headless** functions only (render with Cycles CPU, run scripts) and show a clear "GPU not supported" screen. **No silent fallbacks.**

### 3.4 Build hosts

* GitHub `ubuntu-latest` runners ship an Android NDK (r27+) and CMake. Full deps take several hours: Embree, OIIO, OpenVDB, FFmpeg and OIDN dominate. Plan for per-library caching (`actions/cache` keyed on `versions.cmake` hash + script hash) and splitting the deps across jobs.
* **This cloud session cannot download the NDK.** `dl.google.com` is blocked by its network policy (HTTP 403 from the proxy). Phase 2 can still be written here, but local test builds need that host allowed (or the NDK fetched from another allowed mirror). CI is unaffected.

---

## 4. Proposed upstream-patch budget

Rule: Android code lives in **new files** (`intern/ghost/intern/GHOST_*Android*`, `build_files/cmake/platform/platform_android.cmake`, `source/creator/android/…`, `android/` Gradle project). The table below is the full list of expected edits to existing upstream files, kept as a quilt-style patch series under `patches/` so we can rebase.

| File | Change | Size |
|---|---|---|
| `CMakeLists.txt` | `elseif(ANDROID)` → include `platform_android.cmake`; Android option defaults | ~10 lines |
| `intern/ghost/CMakeLists.txt` | `elseif(ANDROID)` source list | ~10 |
| `intern/ghost/intern/GHOST_ISystem.cc` | `#elif defined(__ANDROID__)` create system | ~6 |
| `intern/ghost/intern/GHOST_ContextVK.{cc,hh}` | Android surface (`VK_KHR_android_surface`), composite alpha, pre-transform | ~40 |
| `source/blender/gpu/vulkan/vk_backend.cc`, `vk_device.cc` | geometryShader optional, mobile vendor IDs, TBDR | ~30 |
| `source/blender/blenlib/BLI_subprocess.hh` | exclude Android | 1 |
| `build_files/cmake/macros.cmake`, `makesdna`/`makesrna`/`datatoc`/`shader_tool`/`msgfmt` CMakeLists | imported host tools | ~25 |

**Total: around 120 lines across ~12 upstream files.** Everything else is additive.

---

## 5. Proposed repository layout (built out in Phase 2+)

```
upstream/blender.lock        # pinned tag + commit
patches/                     # minimal upstream patch series (applied by script)
deps/                        # NDK cross-compile scripts, one per library + toolchain/meson cross files
android/                     # Gradle project (app/, GameActivity glue, Java/Kotlin UI bits)
source/                      # Android-only C++ (GHOST backend, launcher, SAF bridge) copied/overlaid into the tree
scripts/build.sh             # single entry point: deps → host tools → libblender.so → APK
.github/workflows/android.yml
docs/
```

---

## 6. Phase 1 report

**What works / is done**
* Mapped all platform layers (GHOST, GPU, Python, threading, paths, misc POSIX) against Android/bionic, with file:line references.
* Classified all third-party libraries (§2).
* Found useful shortcuts: env-var path overrides (no path patches), an SDL3 GHOST backend that already does Vulkan, Linux-arm64 being officially supported upstream, and CPython 3.13 Android support.

**What failed / could not be verified**
* No on-device data: the mobile-GPU support table (§3.3) comes from documentation and memory. Cells marked *verify* must be checked on real Adreno and Mali devices.
* Could not download the Android NDK in this environment (`dl.google.com` → 403 from the network proxy). Nothing was compiled for Android in Phase 1; this phase was analysis only, as specified.

**Hard blockers and proposed fixes**
1. **Build-time host tools in a cross build** (§3.1). Fix: host-tools stage plus a ~25-line imported-targets patch.
2. **Vulkan minimums vs. mobile drivers** (§3.3). Fix: relax `geometryShader`, add mobile vendor/TBDR handling, fix swapchain alpha and transform. Devices without dynamic rendering, timeline semaphores and BDA cannot run the GUI; they get headless-only (optionally Turnip on Adreno 6xx).
3. **NDK access in this session.** Allow `dl.google.com` in the environment's network settings, or rely on CI only.

**Next (Phase 2):** toolchain files (CMake + meson cross + autotools env), per-library build scripts in dependency order for the **H** set, host-tools stage, and a headless `blender` executable run through `adb shell` against a test `.blend` + Python script.

---

## Addendum (after Phase 1): the official `android` branch

This analysis covered the **v5.3.0 tag only** and missed that upstream Blender maintains an
official `android` branch (and an `ios` branch). That branch already solves several items
above:

- **§1.1 GHOST:** uses the SDL3 backend (`WITH_GHOST_SDL` forced on for Android) with
  `SDLActivity` instead of a new native backend.
- **§1.6 `BLI_subprocess`:** fixed upstream with the same `!defined(__ANDROID__)` guard.
- **§3.1 host tools:** solved by `build_files/cmake/host_tools.cmake` (a host sub-build) plus
  pre-built host libraries.
- **§2 dependencies:** built by Blender's own `build_environment` for Android and shipped as
  `lib/android_arm64`.
- **§3.3 swapchain items 3 (pre-transform), rotation and resize:** handled upstream.

Still open upstream, and therefore in this project's scope:

- **§3.3 items 1, 2, 5–7:** `geometryShader` and the other hard device requirements, mobile
  vendor IDs / TBDR, memory limits, unsupported-device UX.
- **Phase 4–5 UX:** the touch scheme, modifier bar, SAF, autosave and branding.

See `docs/plan.md` for the revised plan.
