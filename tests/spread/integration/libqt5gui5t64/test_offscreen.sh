rootfs="$(install-slices libqt5gui5t64_offscreen)"

# The multiarch directory and the dynamic loader's name differ per arch.
plugin="$(find "$rootfs" -path "*/lib/*-linux-*/qt5/plugins/platforms/libqoffscreen.so" -print -quit)"
loader="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/ld*.so.*" -print -quit)"
test -n "$plugin"
test -n "$loader"

# The dynamic loader fails if any shared library the plugin links against is missing.
chroot "$rootfs" "${loader#"$rootfs"}" --list "${plugin#"$rootfs"}"
