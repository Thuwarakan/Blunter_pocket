# OpenSSL (SSL) – Python `ssl`/`hashlib`. Uses OpenSSL's own `android-arm64` target,
# which locates the NDK through ANDROID_NDK_ROOT and expects `clang` on PATH.
build() {
  unpack SSL
  export ANDROID_NDK_ROOT=$NDK
  export PATH=$TOOLCHAIN/bin:$PATH
  unset CC CXX AR RANLIB AS LD NM STRIP
  ./Configure android-arm64 -D__ANDROID_API__="$ANDROID_API" \
    no-shared no-tests no-docs no-apps no-module \
    --prefix="$PREFIX" --libdir=lib --openssldir=/system/etc/security \
    -fPIC -D__BIONIC_NO_PAGE_SIZE_MACRO
  make -j "$BLA_JOBS" build_libs
  make install_dev
}
