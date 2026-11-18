# OpenJPH (OPENJPH) – HTJ2K, used by OpenEXR.
build() {
  unpack OPENJPH
  apply_blender_patch openjph_table_init_243.diff
  cmake_build -DOJPH_BUILD_TESTS=OFF -DOJPH_ENABLE_TIFF_SUPPORT=OFF \
    -DOJPH_BUILD_EXECUTABLES=OFF
}
