# XZ Utils / liblzma (LZMA) – Python `lzma` module.
build() {
  unpack LZMA
  autotools_build --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo \
    --disable-lzma-links --disable-scripts --disable-doc --disable-nls
}
