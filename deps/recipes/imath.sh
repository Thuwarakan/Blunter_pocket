# Imath (IMATH)
build() {
  unpack IMATH
  cmake_build -DBUILD_TESTING=OFF -DPYTHON=OFF
}
