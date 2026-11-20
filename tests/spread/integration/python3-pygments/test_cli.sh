rootfs="$(install-slices python3-pygments_scripts)"

mkdir -p "$rootfs/tmp/project"
cp cli/* "$rootfs/tmp/project/"

chroot "$rootfs" /usr/bin/pygmentize -V
chroot "$rootfs" /usr/bin/pygmentize \
  -f html \
  -l python \
  /tmp/project/example.py > "$rootfs/tmp/example.html"

test "$(chroot "$rootfs" python3 /tmp/project/verify.py)" = "success"
