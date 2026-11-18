# bzip2 (BZIP2) – Python `bz2` module. Plain Makefile project.
build() {
  unpack BZIP2
  make -j "$BLA_JOBS" libbz2.a CC="$CC" AR="$AR" RANLIB="$RANLIB" \
    CFLAGS="$BLA_CFLAGS -D_FILE_OFFSET_BITS=64"
  install -D -m644 bzlib.h "$PREFIX/include/bzlib.h"
  install -D -m644 libbz2.a "$PREFIX/lib/libbz2.a"
}
