# GMP (GMP) – exact boolean. ARM assembly disabled like Blender (crash #103423).
build() {
  unpack GMP
  apply_blender_patch gmp.diff
  autotools_build --enable-cxx --with-pic --disable-assembly
}
