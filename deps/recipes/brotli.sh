# Brotli (BROTLI) – WOFF2 support in FreeType.
build() {
  unpack BROTLI
  cmake_build -DBROTLI_DISABLE_TESTS=ON -DBROTLI_BUNDLED_MODE=OFF
  # 1.0.x always builds shared + "-static" archives; keep only the archives.
  rm -f "${PREFIX:?}"/lib/*.so* "${PREFIX:?}"/bin/brotli
}
