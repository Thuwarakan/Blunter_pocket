# minizip-ng (MINIZIPNG) – OpenColorIO dependency, same options as Blender.
build() {
  unpack MINIZIPNG
  cmake_build -DMZ_FETCH_LIBS=OFF -DMZ_LIBCOMP=OFF -DMZ_PKCRYPT=OFF -DMZ_WZAES=OFF \
    -DMZ_OPENSSL=OFF -DMZ_SIGNING=OFF -DMZ_PPMD=OFF -DMZ_LZMA=OFF -DMZ_ZSTD=OFF \
    -DMZ_BZIP2=OFF -DMZ_ICONV=OFF -DMZ_ZLIB=ON -DMZ_ZLIB_FLAVOR=zlib \
    -DZLIB_LIBRARY="$LIBDIR/zlib/lib/libz.a" -DZLIB_INCLUDE_DIR="$LIBDIR/zlib/include" \
    -DCMAKE_INSTALL_INCLUDEDIR="$PREFIX/include/minizip-ng"
}
