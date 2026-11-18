# libepoxy (EPOXY) – GL function loader. Blender's unix platform file requires it even
# with the OpenGL backend disabled; upstream epoxy supports Android (EGL/GLES only).
build() {
  unpack EPOXY
  meson_build -Dtests=false -Ddocs=false -Dglx=no -Dx11=false -Degl=yes
}
