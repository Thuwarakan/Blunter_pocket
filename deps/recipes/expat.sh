# Expat (EXPAT) – OpenColorIO dependency. The archive is a git snapshot; CMake is in expat/.
build() {
  unpack EXPAT
  CMAKE_SOURCE_SUBDIR=expat cmake_build -DEXPAT_BUILD_DOCS=OFF -DEXPAT_BUILD_EXAMPLES=OFF \
    -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_TOOLS=OFF -DEXPAT_SHARED_LIBS=OFF
}
