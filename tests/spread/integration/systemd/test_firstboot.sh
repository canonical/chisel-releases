#!/bin/bash
#spellchecker: ignore rootfs firstboot credstore nsystemctl

# What systemd_firstboot adds: a tool that seeds an image root before it ever
# boots, and a unit that does the same on the first boot.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

hash='$6$abcdefgh$ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyzABCD/'

# offline: an image root gets seeded with no systemd running at all
rootfs="$(install-slices systemd_firstboot)"
chroot "$rootfs" /usr/bin/systemd-firstboot --version | grep -Eq '^systemd [0-9]+ '
img="$rootfs/work/img"
mkdir -p "$img/etc" "$img/bin"
printf '#!/bin/sh\n' > "$img/bin/sh"
chmod 755 "$img/bin/sh"

chroot "$rootfs" /usr/bin/systemd-firstboot --root=/work/img \
  --hostname=chisel-test \
  --machine-id=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --root-password-hashed="$hash" \
  --root-shell=/bin/sh

grep -Fxq "chisel-test" "$img/etc/hostname"
grep -Fxq "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "$img/etc/machine-id"
grep -Fq "root:$hash:" "$img/etc/shadow"
grep -Fxq "root:x:0:0:Super User:/root:/bin/sh" "$img/etc/passwd"

# a second run without --force leaves what is already configured alone
cp "$img/etc/passwd" "$rootfs/work/passwd.before"
cp "$img/etc/shadow" "$rootfs/work/shadow.before"
chroot "$rootfs" /usr/bin/systemd-firstboot --root=/work/img \
  --hostname=chisel-other \
  --root-password-hashed='$6$other$other' \
  --root-shell=/bin/sh
grep -Fxq "chisel-test" "$img/etc/hostname"
grep -Fxq "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "$img/etc/machine-id"
cmp "$img/etc/passwd" "$rootfs/work/passwd.before"
cmp "$img/etc/shadow" "$rootfs/work/shadow.before"
clean-rootfs "$rootfs"

# at boot, with every answer handed over as a credential, nothing prompts
rootfs="$(install-slices systemd_firstboot systemd_core)"

mkdir -p "$rootfs/etc/credstore"
printf '%s' "$hash" > "$rootfs/etc/credstore/passwd.hashed-password.root"
printf '%s' "C.UTF-8" > "$rootfs/etc/credstore/firstboot.locale"
printf '%s' "UTC" > "$rootfs/etc/credstore/firstboot.timezone"

# the unit wants a console, and docker runs have none
mkdir -p "$rootfs/etc/systemd/system/systemd-firstboot.service.d"
cat > "$rootfs/etc/systemd/system/systemd-firstboot.service.d/override.conf" <<'EOF'
[Service]
StandardInput=null
StandardOutput=journal
StandardError=journal
EOF

trap 'shutdown_rootfs || true' EXIT
# the unit under test is the one the harness masks by default
BOOT_MASKS=console-getty.service boot_rootfs "$rootfs"
# shellcheck disable=SC2119 # nothing in this closure is expected to fail
assert_failed_units

test "$(nsystemctl show -p ActiveState --value systemd-firstboot.service)" = "active"
test "$(nsystemctl show -p Result --value systemd-firstboot.service)" = "success"
# locale and timezone are this unit's alone; sysusers applies the password too
grep -Fxq "LANG=C.UTF-8" "$rootfs/etc/locale.conf"
test "$(readlink "$rootfs/etc/localtime")" = "../usr/share/zoneinfo/UTC"

shutdown_rootfs
