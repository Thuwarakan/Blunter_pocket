# sse2neon (SSE2NEON) – header only, required by Blender (and OCIO) on ARM.
build() {
  unpack SSE2NEON
  install -D -m644 sse2neon.h "$PREFIX/include/sse2neon.h"
}
