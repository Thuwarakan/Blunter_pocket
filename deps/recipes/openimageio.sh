# OpenImageIO (OPENIMAGEIO) – required. Static, no tools/Python/Qt/OpenCV/FFmpeg.
build() {
  unpack OPENIMAGEIO
  apply_blender_patch openimageio.diff
  apply_blender_patch openimageio_dds_3d_5133.diff
  apply_blender_patch openimageio_psd.diff
  cmake_build -DLINKSTATIC=ON \
    '-DOpenImageIO_REQUIRED_DEPS=WebP;libjpeg-turbo;TIFF;OpenEXR;PNG;OpenJPEG;fmt;Robinmap;ZLIB;pugixml;openjph;TBB' \
    -DUSE_NUKE=OFF -DUSE_OPENVDB=OFF -DUSE_FREETYPE=OFF -DUSE_DCMTK=OFF -DUSE_TBB=ON \
    -DUSE_QT=OFF -DUSE_PYTHON=OFF -DUSE_GIF=OFF -DUSE_OPENCV=OFF -DUSE_OPENJPEG=ON \
    -DUSE_FFMPEG=OFF -DUSE_PTEX=OFF -DUSE_LIBHEIF=OFF -DUSE_LIBRAW=OFF -DUSE_JXL=OFF \
    -DUSE_OPENCOLORIO=ON -DUSE_WEBP=ON -DOIIO_BUILD_TOOLS=OFF -DOIIO_BUILD_TESTS=OFF \
    -DBUILD_TESTING=OFF -DBUILD_DOCS=OFF -DINSTALL_DOCS=OFF -DINSTALL_FONTS=OFF \
    -DSTOP_ON_WARNING=OFF -DUSE_EXTERNAL_PUGIXML=ON -DOpenImageIO_BUILD_MISSING_DEPS="" \
    -DZLIB_ROOT="$LIBDIR/zlib" \
    -DPNG_LIBRARY="$LIBDIR/png/lib/libpng.a" -DPNG_PNG_INCLUDE_DIR="$LIBDIR/png/include" \
    -DTIFF_LIBRARY="$LIBDIR/tiff/lib/libtiff.a" -DTIFF_INCLUDE_DIR="$LIBDIR/tiff/include" \
    -DJPEG_ROOT="$LIBDIR/jpeg" -Dlibjpeg-turbo_ROOT="$LIBDIR/jpeg" \
    -DOpenJPEG_ROOT="$LIBDIR/openjpeg" \
    -Dpugixml_DIR="$LIBDIR/pugixml/lib/cmake/pugixml" \
    -DOpenColorIO_DIR="$LIBDIR/opencolorio/lib/cmake/OpenColorIO" \
    -DFMT_INCLUDE_DIR="$LIBDIR/fmt/include" -Dfmt_ROOT="$LIBDIR/fmt" \
    -DRobinmap_ROOT="$LIBDIR/robinmap" -DWebP_ROOT="$LIBDIR/webp" \
    -DOpenEXR_ROOT="$LIBDIR/openexr" -DImath_ROOT="$LIBDIR/imath" \
    -DTBB_ROOT="$LIBDIR/tbb" -Dlibdeflate_ROOT="$LIBDIR/deflate" \
    -Dopenjph_DIR="$LIBDIR/openjph/lib/cmake/openjph"
}
