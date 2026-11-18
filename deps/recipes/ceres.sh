# Ceres solver (CERES) – libmv (motion tracking).
build() {
  unpack CERES
  cmake_build -DBUILD_TESTING=OFF -DBUILD_BENCHMARKS=OFF -DBUILD_EXAMPLES=OFF \
    -DUSE_CUDA=OFF -DSUITESPARSE=OFF -DLAPACK=OFF -DPROVIDE_UNINSTALL_TARGET=OFF \
    -Dabsl_DIR="$LIBDIR/abseil/lib/cmake/absl" \
    -DEigen3_DIR="$LIBDIR/eigen/share/eigen3/cmake" \
    -DTBB_DIR="$LIBDIR/tbb/lib/cmake/TBB"
}
