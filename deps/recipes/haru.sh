# libharu (HARU) – Grease Pencil PDF export.
build() {
  unpack HARU
  cmake_build -DLIBHPDF_EXAMPLES=OFF -DLIBHPDF_ENABLE_EXCEPTIONS=ON -DLIBHPDF_SHARED=OFF \
    -DLIBHPDF_STATIC=ON -DZLIB_ROOT="$LIBDIR/zlib" -DPNG_ROOT="$LIBDIR/png"
  rm -f "${PREFIX:?}"/lib/*.so*
}
