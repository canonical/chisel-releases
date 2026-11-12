rootfs="$(install-slices python3-pytest_scripts)"

mkdir -p "$rootfs/dev" "$rootfs/tmp/project"
chmod 1777 "$rootfs/tmp"
touch "$rootfs/dev/null"
cp cli/* "$rootfs/tmp/project/"

chroot "$rootfs" /usr/bin/py.test --version
chroot "$rootfs" /usr/bin/py.test-3 --version
chroot "$rootfs" /usr/bin/pytest --version
chroot "$rootfs" /usr/bin/pytest-3 --version
test "$(chroot "$rootfs" python3 /tmp/project/verify.py)" = "success"
