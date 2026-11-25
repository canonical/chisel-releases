#!/bin/bash
#spellchecker: ignore rootfs sysusers nologin

# systemd-sysusers on its own: it applies sysusers.d fragments to an image
# root with no systemd running, which is how an image build uses it.

rootfs="$(install-slices systemd_sysusers)"

chroot "$rootfs" /usr/bin/systemd-sysusers --version | grep -Eq '^systemd [0-9]+ '
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

# an image root with empty account databases, and a fragment for it
img="$rootfs/work/img"
mkdir -p "$img/etc"
: > "$img/etc/passwd"
: > "$img/etc/group"
cat > "$rootfs/work/chisel.conf" <<'EOF'
g chisel-group 4242
u chisel-user 4243:chisel-group "Chisel test user" /var/lib/chisel /usr/sbin/nologin
EOF

chroot "$rootfs" /usr/bin/systemd-sysusers --root=/work/img /work/chisel.conf
grep -Fxq "chisel-group:x:4242:" "$img/etc/group"
grep -Fxq "chisel-user:x:4243:4242:Chisel test user:/var/lib/chisel:/usr/sbin/nologin" "$img/etc/passwd"

# applying the same fragment again changes nothing
cp "$img/etc/passwd" "$rootfs/work/passwd.before"
chroot "$rootfs" /usr/bin/systemd-sysusers --root=/work/img /work/chisel.conf
cmp "$img/etc/passwd" "$rootfs/work/passwd.before"
umount "$rootfs/proc"
clean-rootfs "$rootfs"

# with the fragments systemd ships, those are the ones it reads
rootfs="$(install-slices systemd_sysusers systemd_sysusers-config)"
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
chroot "$rootfs" systemd-sysusers --cat-config | grep -Fq "/usr/lib/sysusers.d/systemd-journal.conf"
