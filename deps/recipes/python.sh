# CPython (PYTHON) – embedded interpreter. CPython >= 3.13 supports Android upstream
# (PEP 738); configure flags follow its Android/android.py, except that:
#   * libpython is static (Blender links it into its own binary, as on Linux), and
#   * every stdlib extension module is built *into* libpython (MODULE_BUILDTYPE=static),
#     because the headless test binary is a fully static executable without dlopen().
#
# Needs a build-machine Python of the same major.minor (python3.13) on PATH.
build() {
  unpack PYTHON
  local short; short=$(echo "$DEP_VERSION" | cut -d. -f1-2)
  local build_python
  build_python=$(command -v "python$short" || true)
  [[ -n "$build_python" ]] || die "python$short is required on the build machine"

  autotools_env
  # liblzma/libffi/sqlite are found through pkg-config (PKG_CONFIG_LIBDIR from
  # autotools_env), zlib/bzip2 through CPPFLAGS/LDFLAGS, OpenSSL explicitly.
  export LDFLAGS="$LDFLAGS -lm"
  export MODULE_BUILDTYPE=static
  export CONFIG_SITE=""

  (cd "$BUILD_DIR" && "$SRC_DIR/configure" \
      --host="$TARGET_TRIPLE" --build="$(uname -m)-pc-linux-gnu" \
      --with-build-python="$build_python" \
      --prefix="$PREFIX" \
      --disable-shared --without-ensurepip --disable-test-modules \
      --without-readline --with-openssl="$LIBDIR/openssl" --with-openssl-rpath=no \
      py_cv_module__tkinter=n/a py_cv_module__curses=n/a \
      py_cv_module__curses_panel=n/a py_cv_module__dbm=n/a py_cv_module__gdbm=n/a \
      py_cv_module_readline=n/a py_cv_module__uuid=n/a py_cv_module_xxlimited=n/a \
      py_cv_module_xxlimited_35=n/a py_cv_module__ctypes_test=n/a)

  make -C "$BUILD_DIR" -j "$BLA_JOBS"
  make -C "$BUILD_DIR" install

  # The test-suite is ~100 MB and never used inside the app.
  rm -rf "${PREFIX:?}/lib/python$short/test" "${PREFIX:?}/lib/python$short/idlelib" \
         "${PREFIX:?}/lib/python$short/tkinter" "${PREFIX:?}/lib/python$short/turtledemo"

  # Record which libraries a static link of libpython needs (consumed by the Blender
  # configure step, see android/cmake/blender_android_config.cmake).
  cat > "$PREFIX/link_deps.txt" <<EOF
$LIBDIR/openssl/lib/libssl.a
$LIBDIR/openssl/lib/libcrypto.a
$LIBDIR/libffi/lib/libffi.a
$LIBDIR/sqlite/lib/libsqlite3.a
$LIBDIR/xz/lib/liblzma.a
$LIBDIR/bzip2/lib/libbz2.a
$LIBDIR/zlib/lib/libz.a
EOF
}
