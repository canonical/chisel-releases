rootfs="$(install-slices python3-build_libs)"

mkdir -p "$rootfs/tmp/project" "$rootfs/tmp/wheels"
cp api/* "$rootfs/tmp/project/"

test "$(chroot "$rootfs" python3 /tmp/project/verify.py)" = "success"
