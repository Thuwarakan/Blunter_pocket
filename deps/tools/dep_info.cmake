# SPDX-License-Identifier: GPL-3.0-or-later
# Print download metadata of one dependency, taken verbatim from Blender's
# build_files/build_environment/cmake/versions.cmake, so the Android build always
# uses exactly the versions/hashes of the upstream release we are pinned to.
#
# Usage: cmake -DVERSIONS=<path/to/versions.cmake> -DDEP=ZLIB -P dep_info.cmake
# Output (shell-sourceable):
#   DEP_VERSION=... DEP_URI=... DEP_FILE=... DEP_HASH=... DEP_HASH_TYPE=...
if(NOT DEFINED VERSIONS OR NOT DEFINED DEP)
  message(FATAL_ERROR "VERSIONS and DEP must be defined")
endif()
# versions.cmake references a few variables from the surrounding build; give them
# harmless values so that every URI expands.
set(BLENDER_PLATFORM_ARM ON)
set(BUILD_MODE Release)
include(${VERSIONS})
foreach(field VERSION URI FILE HASH HASH_TYPE)
  if(DEFINED ${DEP}_${field})
    execute_process(COMMAND ${CMAKE_COMMAND} -E echo "DEP_${field}='${${DEP}_${field}}'")
  endif()
endforeach()
