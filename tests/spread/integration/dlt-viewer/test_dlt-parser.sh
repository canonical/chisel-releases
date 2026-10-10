rootfs="$(install-slices dlt-viewer_dlt-parser)"

# The dynamic loader's name differs per arch.
loader="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/ld*.so.*" -print -quit)"
test -n "$loader"

# The dynamic loader fails if any shared library dlt-parser links against is missing.
chroot "$rootfs" "${loader#"$rootfs"}" --list /usr/bin/dlt-parser
