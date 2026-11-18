# SPDX-License-Identifier: GPL-3.0-or-later
#
# Initial CMake cache (`cmake -C`) for the Phase 2 *headless* Android build of Blender:
# a fully static AArch64 executable that can open .blend files, run Python and render
# with Cycles (CPU). No GPU, windowing or audio.
#
# Required -D variables from the caller (scripts/build_blender.sh passes them):
#   LIBDIR             $BUILD/lib/android_arm64 (output of deps/build_deps.sh)
#   HOST_PYTHON        build-machine python3.13 (runs code generators at build time)

if(NOT DEFINED LIBDIR OR NOT DEFINED HOST_PYTHON)
  message(FATAL_ERROR "LIBDIR and HOST_PYTHON must be passed with -D")
endif()

macro(bla_set var value)
  set(${var} ${value} CACHE STRING "" FORCE)
endmacro()
macro(bla_option var value)
  set(${var} ${value} CACHE BOOL "" FORCE)
endmacro()

# --- Libraries ---------------------------------------------------------------
bla_set(LIBDIR "${LIBDIR}")
bla_option(WITH_LIBS_PRECOMPILED ON)
bla_option(WITH_STATIC_LIBS ON)
# Fail at configure time instead of silently dropping a feature whose library is missing.
bla_option(WITH_STRICT_BUILD_OPTIONS ON)
bla_option(WITH_CPU_CHECK OFF)
bla_option(WITH_INSTALL_PORTABLE ON)

# --- Linking -------------------------------------------------------------------
# Fully static executables: needed for the generated build tools (makesdna, makesrna,
# ...), which run on the build machine through qemu-aarch64 (binfmt_misc) and can't
# use Android's dynamic linker, and for the headless test binary itself.
bla_set(CMAKE_EXE_LINKER_FLAGS "-static -Wl,-z,max-page-size=16384")
bla_option(WITH_LINKER_LLD OFF)   # The NDK clang already uses lld.
bla_option(WITH_LINKER_MOLD OFF)

# --- Windowing / GPU / input -------------------------------------------------------
bla_option(WITH_HEADLESS ON)
bla_option(WITH_GHOST_X11 OFF)
bla_option(WITH_GHOST_WAYLAND OFF)
bla_option(WITH_GHOST_SDL OFF)
bla_option(WITH_GHOST_DBUS OFF)
bla_option(WITH_OPENGL_BACKEND OFF)
bla_option(WITH_VULKAN_BACKEND OFF)
bla_option(WITH_INPUT_NDOF OFF)
bla_option(WITH_INPUT_IME OFF)
bla_option(WITH_XR_OPENXR OFF)
bla_option(WITH_BLENDER_THUMBNAILER OFF)

# --- Audio / video (Phase 4+) --------------------------------------------------------
bla_option(WITH_AUDASPACE OFF)
bla_option(WITH_OPENAL OFF)
bla_option(WITH_SDL OFF)
bla_option(WITH_JACK OFF)
bla_option(WITH_PULSEAUDIO OFF)
bla_option(WITH_PIPEWIRE OFF)
bla_option(WITH_CODEC_FFMPEG OFF)
bla_option(WITH_CODEC_SNDFILE OFF)
bla_option(WITH_RUBBERBAND OFF)
bla_option(WITH_OPENTIMELINEIO OFF)

# --- Python --------------------------------------------------------------------------
bla_option(WITH_PYTHON ON)
bla_option(WITH_PYTHON_INSTALL ON)
bla_option(WITH_PYTHON_NUMPY OFF)          # NumPy cross-build comes after the MVP.
bla_option(WITH_PYTHON_INSTALL_NUMPY OFF)
bla_option(WITH_PYTHON_INSTALL_REQUESTS OFF)
bla_option(WITH_PYTHON_INSTALL_ZSTANDARD OFF)
bla_set(PYTHON_VERSION 3.13)
bla_set(PYTHON_ROOT_DIR "${LIBDIR}/python")
bla_set(PYTHON_EXECUTABLE "${HOST_PYTHON}")
# Static libpython with built-in extension modules needs their libraries too.
file(STRINGS "${LIBDIR}/python/link_deps.txt" _py_link_deps)
bla_set(PYTHON_LIBRARY "${LIBDIR}/python/lib/libpython3.13.a;${_py_link_deps}")
unset(_py_link_deps)

# --- Cycles: CPU only ------------------------------------------------------------------
bla_option(WITH_CYCLES ON)
bla_option(WITH_CYCLES_OSL OFF)
bla_option(WITH_CYCLES_PATH_GUIDING OFF)    # OpenPGL: later.
bla_option(WITH_CYCLES_DEVICE_CUDA OFF)
bla_option(WITH_CYCLES_DEVICE_OPTIX OFF)
bla_option(WITH_CYCLES_DEVICE_HIP OFF)
bla_option(WITH_CYCLES_DEVICE_HIPRT OFF)
bla_option(WITH_CYCLES_DEVICE_ONEAPI OFF)
bla_option(WITH_CYCLES_DEVICE_METAL OFF)
bla_option(WITH_CYCLES_CUDA_BINARIES OFF)
bla_option(WITH_CYCLES_HIP_BINARIES OFF)
bla_option(WITH_CYCLES_ONEAPI_BINARIES OFF)
bla_option(WITH_CUDA_DYNLOAD OFF)
bla_option(WITH_EMBREE OFF)                 # Embree ARM build: later (Cycles uses BVH2).
bla_option(WITH_OPENIMAGEDENOISE OFF)
bla_option(WITH_LLVM OFF)

# --- Features whose libraries come later ---------------------------------------------
bla_option(WITH_OPENVDB OFF)
bla_option(WITH_NANOVDB OFF)
bla_option(WITH_ALEMBIC OFF)
bla_option(WITH_USD OFF)
bla_option(WITH_MATERIALX OFF)
bla_option(WITH_HYDRA OFF)
bla_option(WITH_JOLT OFF)
bla_option(WITH_DRACO OFF)
bla_option(WITH_MESHOPTIMIZER OFF)
bla_option(WITH_KTX OFF)
bla_option(WITH_HARFBUZZ OFF)
bla_option(WITH_FRIBIDI OFF)

# --- Features built in this phase ---------------------------------------------------
bla_option(WITH_TBB ON)
bla_option(WITH_TBB_MALLOC_PROXY OFF)
bla_option(WITH_OPENSUBDIV ON)
bla_option(WITH_FFTW3 ON)
bla_option(WITH_GMP ON)
bla_option(WITH_MANIFOLD ON)
bla_option(WITH_POTRACE ON)
bla_option(WITH_HARU ON)
bla_option(WITH_PUGIXML ON)
bla_option(WITH_IMAGE_OPENJPEG ON)
bla_option(WITH_IMAGE_WEBP ON)
bla_option(WITH_LIBMV ON)
bla_option(WITH_MOD_FLUID ON)
bla_option(WITH_INTERNATIONAL ON)

# --- Misc -------------------------------------------------------------------------
bla_option(WITH_GTESTS OFF)
bla_option(WITH_DOC_MANPAGE OFF)
bla_option(WITH_COMPILER_ASAN OFF)
bla_set(CMAKE_BUILD_TYPE Release)
