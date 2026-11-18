# {fmt} (FMT)
build() {
  unpack FMT
  cmake_build -DFMT_TEST=OFF -DFMT_DOC=OFF
}
