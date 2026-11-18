# libtiff (TIFF)
build() {
  unpack TIFF
  cmake_build -Dlzma=OFF -Djbig=OFF -Dzstd=OFF -Dwebp=OFF -Dlerc=OFF -Dlibdeflate=ON \
    -Dtiff-tests=OFF -Dtiff-tools=OFF -Dtiff-docs=OFF -Dtiff-contrib=OFF -Dsphinx=OFF \
    -Dcxx=ON -DZLIB_ROOT="$LIBDIR/zlib" \
    -DJPEG_LIBRARY="$LIBDIR/jpeg/lib/libjpeg.a" -DJPEG_INCLUDE_DIR="$LIBDIR/jpeg/include" \
    -DDeflate_LIBRARY="$LIBDIR/deflate/lib/libdeflate.a" \
    -DDeflate_INCLUDE_DIR="$LIBDIR/deflate/include"
}
