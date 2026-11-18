# OpenColorIO (OPENCOLORIO) – required. SIMD on ARM goes through sse2neon.
build() {
  unpack OPENCOLORIO
  cmake_build -DOCIO_BUILD_APPS=OFF -DOCIO_BUILD_PYTHON=OFF -DOCIO_BUILD_NUKE=OFF \
    -DOCIO_BUILD_JAVA=OFF -DOCIO_BUILD_DOCS=OFF -DOCIO_BUILD_TESTS=OFF \
    -DOCIO_BUILD_GPU_TESTS=OFF -DOCIO_USE_SIMD=ON -DOCIO_USE_SSE=OFF \
    -DOCIO_INSTALL_EXT_PACKAGES=NONE \
    -Dexpat_ROOT="$LIBDIR/expat" \
    -Dyaml-cpp_DIR="$LIBDIR/yamlcpp/lib/cmake/yaml-cpp" \
    -Dpystring_ROOT="$LIBDIR/pystring" \
    -DImath_ROOT="$LIBDIR/imath" \
    -Dminizip-ng_ROOT="$LIBDIR/minizipng" \
    -Dminizip-ng_INCLUDE_DIR="$LIBDIR/minizipng/include/minizip-ng/minizip" \
    -Dminizip-ng_LIBRARY="$LIBDIR/minizipng/lib/libminizip.a" \
    -Dsse2neon_ROOT="$LIBDIR/sse2neon" \
    -Dsse2neon_INCLUDE_DIR="$LIBDIR/sse2neon/include" \
    -DZLIB_LIBRARY="$LIBDIR/zlib/lib/libz.a" -DZLIB_INCLUDE_DIR="$LIBDIR/zlib/include"
  # Same as Blender's Linux harvest: keep OCIO's private static deps next to it.
  cp "$LIBDIR/yamlcpp/lib/libyaml-cpp.a" "$LIBDIR/expat/lib/libexpat.a" \
     "$LIBDIR/pystring/lib/libpystring.a" "$PREFIX/lib/"
}
