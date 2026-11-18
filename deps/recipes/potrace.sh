# Potrace (POTRACE) – Grease Pencil trace, built with Blender's CMakeLists.
build() {
  unpack POTRACE
  cp "$BLENDER_DEPS_PATCHES/cmakelists_potrace.txt" CMakeLists.txt
  cmake_build
}
