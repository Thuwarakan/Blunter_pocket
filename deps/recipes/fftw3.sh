# FFTW (FFTW) – double and float variants, like Blender's Linux build.
build() {
  unpack FFTW
  local src=$SRC_DIR
  autotools_build --enable-threads --disable-fortran --disable-doc
  # Float build with NEON kernels, into the same prefix.
  BUILD_DIR=$BLA_WORK/$RECIPE_NAME/build-float
  mkdir -p "$BUILD_DIR"
  SRC_DIR=$src autotools_build --enable-threads --disable-fortran --disable-doc \
    --enable-float --enable-neon
}
