# libffi (FFI) – Python `ctypes`.
build() {
  unpack FFI
  autotools_build --disable-docs --disable-multi-os-directory --with-pic
}
