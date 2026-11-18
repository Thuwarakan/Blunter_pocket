# OpenEXR (OPENEXR) – required.
build() {
  unpack OPENEXR
  apply_blender_patch openexr_deflate_cmake.diff
  apply_blender_patch openexr_2594.diff
  cmake_build -DOPENEXR_BUILD_BOTH_STATIC_SHARED=OFF -DBUILD_TESTING=OFF \
    -DOPENEXR_BUILD_PYTHON=OFF -DOPENEXR_INSTALL_TOOLS=OFF -DOPENEXR_BUILD_TOOLS=OFF \
    -DOPENEXR_BUILD_EXAMPLES=OFF -DOPENEXR_INSTALL_EXAMPLES=OFF \
    -DOPENEXR_FORCE_INTERNAL_DEFLATE=OFF -DOPENEXR_FORCE_INTERNAL_OPENJPH=OFF \
    -DOPENEXR_FORCE_INTERNAL_IMATH=OFF \
    -DImath_DIR="$LIBDIR/imath/lib/cmake/Imath" \
    -Dlibdeflate_DIR="$LIBDIR/deflate/lib/cmake/libdeflate" \
    -Dopenjph_DIR="$LIBDIR/openjph/lib/cmake/openjph"
}
