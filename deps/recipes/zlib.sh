# zlib (ZLIB) – compression, required.
build() {
  unpack ZLIB
  cmake_build -DZLIB_BUILD_EXAMPLES=OFF
  rm -f "${PREFIX:?}"/lib/libz.so*
}
