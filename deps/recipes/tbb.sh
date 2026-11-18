# oneTBB (TBB) – upstream supports Android. The malloc *proxy* (libc malloc override)
# is disabled: replacing bionic's allocator is not safe.
build() {
  unpack TBB
  cmake_build -DTBB_TEST=OFF -DTBB_EXAMPLES=OFF -DTBB_STRICT=OFF \
    -DTBBMALLOC_BUILD=ON -DTBBMALLOC_PROXY_BUILD=OFF \
    -DTBB_DISABLE_HWLOC_AUTOMATIC_SEARCH=ON -DTBB_ENABLE_IPO=OFF
}
