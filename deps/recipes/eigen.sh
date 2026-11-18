# Eigen (EIGEN) – header only.
build() {
  unpack EIGEN
  apply_blender_patch eigen_tbb_support.diff
  cmake_build -DBUILD_TESTING=OFF -DEIGEN_BUILD_DOC=OFF -DEIGEN_BUILD_BLAS=OFF \
    -DEIGEN_BUILD_LAPACK=OFF -DEIGEN_BUILD_TESTING=OFF -DEIGEN_BUILD_DEMOS=OFF
}
