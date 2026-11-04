rootfs="$(install-slices dlt-viewer_libs)"

# The multiarch directory and the dynamic loader's name differ per arch.
lib="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/libqdlt.so" -print -quit)"
loader="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/ld*.so.*" -print -quit)"
test -n "$lib"
test -n "$loader"

# The dynamic loader fails if any shared library libqdlt links against is missing.
chroot "$rootfs" "${loader#"$rootfs"}" --list "${lib#"$rootfs"}"
