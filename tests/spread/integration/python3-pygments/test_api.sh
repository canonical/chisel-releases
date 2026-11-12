rootfs="$(install-slices python3-pygments_libs)"

mkdir -p "$rootfs/tmp/project"
cp api/* "$rootfs/tmp/project/"

test "$(chroot "$rootfs" python3 /tmp/project/verify.py)" = "success"
