# pystring (PYSTRING) – OpenColorIO dependency, built with Blender's CMakeLists.
build() {
  unpack PYSTRING
  cp "$BLENDER_DEPS_PATCHES/cmakelists_pystring.txt" CMakeLists.txt
  cmake_build
}
