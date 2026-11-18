# libjpeg-turbo (JPEG) – upstream supports Android, NEON SIMD.
build() {
  unpack JPEG
  cmake_build -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_JPEG8=ON -DWITH_TURBOJPEG=OFF \
    -DWITH_SIMD=ON
  rm -rf "${PREFIX:?}/bin"
}
