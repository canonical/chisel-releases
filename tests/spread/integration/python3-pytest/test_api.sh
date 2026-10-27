rootfs="$(install-slices python3-pytest_libs)"

mkdir -p "$rootfs/dev" "$rootfs/tmp/project"
chmod 1777 "$rootfs/tmp"
touch "$rootfs/dev/null"
cp api/* "$rootfs/tmp/project/"

test "$(chroot "$rootfs" python3 /tmp/project/verify.py)" = "success"
