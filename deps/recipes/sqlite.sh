# SQLite (SQLITE) – Python `sqlite3`. Built straight from the amalgamation, which avoids
# cross-compiling the autosetup-based configure script.
build() {
  unpack SQLITE
  local defs="-DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS4
              -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_MATH_FUNCTIONS
              -DSQLITE_ENABLE_COLUMN_METADATA -DHAVE_USLEEP=1"
  # shellcheck disable=SC2086
  "$CC" $BLA_CFLAGS $defs -c sqlite3.c -o "$BUILD_DIR/sqlite3.o"
  "$AR" rcs "$BUILD_DIR/libsqlite3.a" "$BUILD_DIR/sqlite3.o"
  install -D -m644 sqlite3.h "$PREFIX/include/sqlite3.h"
  install -D -m644 sqlite3ext.h "$PREFIX/include/sqlite3ext.h"
  install -D -m644 "$BUILD_DIR/libsqlite3.a" "$PREFIX/lib/libsqlite3.a"
  mkdir -p "$PREFIX/lib/pkgconfig"
  cat > "$PREFIX/lib/pkgconfig/sqlite3.pc" <<PC
prefix=$PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include
Name: SQLite
Description: SQL database engine
Version: $DEP_VERSION
Libs: -L\${libdir} -lsqlite3
Libs.private: -lm -ldl
Cflags: -I\${includedir}
PC
}
