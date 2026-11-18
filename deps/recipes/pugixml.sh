# pugixml (PUGIXML)
build() {
  unpack PUGIXML
  cmake_build -DPUGIXML_BUILD_TESTS=OFF
}
