# libpng (PNG)
build() {
  unpack PNG
  cmake_build -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF -DPNG_TOOLS=OFF \
    -DPNG_FRAMEWORK=OFF -DPNG_HARDWARE_OPTIMIZATIONS=ON -DPNG_ARM_NEON=on \
    -DZLIB_ROOT="$LIBDIR/zlib"
  rm -f "${PREFIX:?}"/lib/*.so*
}
