rootfs="$(install-slices python3-build_scripts)"

mkdir -p "$rootfs/tmp/project"
cp cli/* "$rootfs/tmp/project/"

chroot "$rootfs" /usr/bin/pyproject-build --version
chroot "$rootfs" /usr/bin/pyproject-build \
  --no-isolation \
  --outdir /tmp/dist \
  --sdist \
  --wheel \
  /tmp/project

test "$(chroot "$rootfs" python3 /tmp/project/verify.py)" = "success"
