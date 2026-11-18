# SPDX-License-Identifier: GPL-3.0-or-later
#
# CMake toolchain used for every CMake-based dependency and for Blender itself.
# Wraps the NDK's toolchain file and fixes library discovery so that:
#   * packages installed in our LIBDIR (one sub-folder per library, listed in
#     CMAKE_PREFIX_PATH) are found without being re-rooted under the NDK sysroot;
#   * the build machine's own /usr, /usr/local headers and libraries are never used.
#
# Expected cache variables: ANDROID_ABI, ANDROID_PLATFORM, ANDROID_STL (forwarded to
# the NDK file), optionally BLA_LIBDIR.

if(NOT DEFINED ENV{NDK} AND NOT DEFINED ANDROID_NDK)
  message(FATAL_ERROR "Set the NDK environment variable (path to the Android NDK r27+).")
endif()
if(NOT DEFINED ANDROID_NDK)
  set(ANDROID_NDK "$ENV{NDK}")
endif()

include("${ANDROID_NDK}/build/cmake/android.toolchain.cmake")

# Search both re-rooted (NDK sysroot) and plain paths, so absolute LIBDIR prefixes
# from CMAKE_PREFIX_PATH work. Programs always come from the host.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)

# ...but never the host system directories.
set(CMAKE_IGNORE_PREFIX_PATH /usr /usr/local /opt /snap)
set(CMAKE_IGNORE_PATH
  /usr/include /usr/local/include
  /usr/lib /usr/lib64 /usr/local/lib /usr/lib/x86_64-linux-gnu
)
set(CMAKE_FIND_USE_PACKAGE_REGISTRY OFF)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY OFF)
set(CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY ON)

# pkg-config: only look in our LIBDIR.
if(DEFINED BLA_LIBDIR)
  file(GLOB _bla_pc_dirs "${BLA_LIBDIR}/*/lib/pkgconfig" "${BLA_LIBDIR}/*/share/pkgconfig")
  string(REPLACE ";" ":" _bla_pc_dirs "${_bla_pc_dirs}")
  set(ENV{PKG_CONFIG_LIBDIR} "${_bla_pc_dirs}")
  set(ENV{PKG_CONFIG_PATH} "")
  unset(_bla_pc_dirs)
endif()
