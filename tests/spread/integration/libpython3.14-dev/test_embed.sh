rootfs="$(install-slices gcc_gcc libpython3.14-dev_libs)"

mkdir -p "$rootfs/tmp"
cp embed-test.c "$rootfs/tmp/"

libpython="$(find "$rootfs/usr/lib" -path "*-linux-*/libpython3.14.so" -print -quit)"
test -n "$libpython"
libdir="$(dirname "${libpython#"$rootfs"}")"

chroot "$rootfs" gcc \
  -I/usr/include/python3.14 \
  /tmp/embed-test.c \
  -L"$libdir" \
  -lpython3.14 \
  -ldl \
  -lm \
  -o /tmp/embed-test
chroot "$rootfs" /tmp/embed-test
