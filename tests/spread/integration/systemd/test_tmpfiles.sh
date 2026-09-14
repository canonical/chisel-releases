#!/bin/bash
#spellchecker: ignore rootfs tmpfiles

# systemd-tmpfiles on its own: it applies tmpfiles.d fragments to an image
# root with no systemd running, which is how an image build uses it.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

rootfs="$(install-slices systemd_tmpfiles)"

assert_version "$rootfs" /usr/bin/systemd-tmpfiles
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
