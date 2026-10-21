#!/bin/bash
#spellchecker: ignore rootfs tmpfiles

# systemd-tmpfiles on its own: it applies tmpfiles.d fragments to an image
# root with no systemd running, which is how an image build uses it.

rootfs="$(install-slices systemd_tmpfiles)"

chroot "$rootfs" /usr/bin/systemd-tmpfiles --version | grep -Eq '^systemd [0-9]+ '
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

# an image root with something stale in it, and a fragment for it
img="$rootfs/work/img"
mkdir -p "$img/etc" "$img/var/lib/stale"
: > "$img/var/lib/stale/leftover"
cat > "$rootfs/work/chisel.conf" <<'EOF'
d /var/lib/chisel 0750 - - -
L /var/run - - - - ../run
f /etc/chisel.conf 0640 - - - chisel
R /var/lib/stale
EOF

chroot "$rootfs" /usr/bin/systemd-tmpfiles --create --remove --root=/work/img /work/chisel.conf
test "$(stat -c '%a' "$img/var/lib/chisel")" = "750"
test "$(readlink "$img/var/run")" = "../run"
test "$(stat -c '%a' "$img/etc/chisel.conf")" = "640"
grep -Fxq "chisel" "$img/etc/chisel.conf"
test ! -e "$img/var/lib/stale"
umount "$rootfs/proc"
clean-rootfs "$rootfs"

# with the fragments systemd ships, those are the ones it reads
rootfs="$(install-slices systemd_tmpfiles systemd_tmpfiles-config)"
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
chroot "$rootfs" systemd-tmpfiles --cat-config | grep -Fq "/usr/lib/tmpfiles.d/20-systemd-varlink.conf"
