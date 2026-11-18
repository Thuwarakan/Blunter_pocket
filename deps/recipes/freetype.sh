# FreeType (FREETYPE) – same feature set as Blender's desktop build.
build() {
  unpack FREETYPE
  cmake_build -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_PNG=ON \
    -DFT_REQUIRE_BROTLI=ON -DFT_REQUIRE_ZLIB=ON \
    -DBROTLIDEC_INCLUDE_DIRS="$LIBDIR/brotli/include" \
    -DBROTLIDEC_LIBRARIES="$LIBDIR/brotli/lib/libbrotlidec-static.a;$LIBDIR/brotli/lib/libbrotlicommon-static.a" \
    -DZLIB_ROOT="$LIBDIR/zlib"
}
