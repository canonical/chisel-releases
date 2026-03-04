#!/usr/bin/env bash
# spellchecker: ignore rootfs  maintscripts MAINTSCRIPT testalias

rootfs="$(install-slices init-system-helpers_deb-systemd-helper)"

mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"  # needed for masking/unmasking

# export _DEB_SYSTEMD_HELPER_DEBUG=1

# Test invalid arguments
chroot "$rootfs" deb-systemd-helper --foo 2>&1 || true | \
    grep -q "/usr/bin/deb-systemd-helper is a program which should be called by dpkg maintscripts only."

# set env var as if called from dpkg
export DPKG_MAINTSCRIPT_PACKAGE=test

# test missing unit file
(chroot "$rootfs" deb-systemd-helper enable test.service 2>&1 || true) |
    grep -q "unable to read test.service"

unit_file="$rootfs/usr/lib/systemd/system/test.service"

# make a test unit file
mkdir -p "$(dirname "$unit_file")"
cat > "$unit_file" <<'EOF'
[Unit]
Description=Test Service

[Service]
ExecStart=/bin/true

[Install]
WantedBy=multi-user.target
EOF

chroot "$rootfs" deb-systemd-helper is-enabled test.service 2>&1 | grep -qx "disabled"
chroot "$rootfs" deb-systemd-helper enable test.service
chroot "$rootfs" deb-systemd-helper is-enabled test.service 2>&1 | grep -qx "enabled"

service_symlink="$rootfs/etc/systemd/system/multi-user.target.wants/test.service"
state_file="$rootfs/var/lib/systemd/deb-systemd-helper-enabled/test.service.dsh-also"
override_file="$rootfs/etc/systemd/system/test.service" # created during masking / unmasking

# check symlink and the state file are now present
test -L "$service_symlink"
test "$(readlink -f "$service_symlink")" = "/usr/lib/systemd/system/test.service"
test -f "$state_file"
test ! -e "$override_file"
grep -qx "/etc/systemd/system/multi-user.target.wants/test.service" "$state_file"

chroot "$rootfs" deb-systemd-helper debian-installed test.service

# disable the service
chroot "$rootfs" deb-systemd-helper disable test.service
chroot "$rootfs" deb-systemd-helper is-enabled test.service 2>&1 | grep -qx "disabled"

# check symlink and the state file 
test ! -e "$service_symlink"
test -f "$state_file"

# purge the state file
_DEB_SYSTEMD_HELPER_PURGE=1 chroot "$rootfs" deb-systemd-helper disable test.service
test ! -f "$state_file"

# test service masking and unmasking
chroot "$rootfs" deb-systemd-helper enable test.service
test ! -e "$override_file"
chroot "$rootfs" deb-systemd-helper mask test.service
test -L "$override_file"
test "$(readlink -f "$override_file")" = "/dev/null"
test -f "$rootfs/var/lib/systemd/deb-systemd-helper-masked/test.service"
chroot "$rootfs" deb-systemd-helper is-enabled test.service

chroot "$rootfs" deb-systemd-helper unmask test.service
test ! -e "$override_file"
test ! -f "$rootfs/var/lib/systemd/deb-systemd-helper-masked/test.service"

# test update-state with no changes
chroot "$rootfs" deb-systemd-helper is-enabled test.service 2>&1 | grep -qx "enabled"
chroot "$rootfs" deb-systemd-helper update-state test.service
chroot "$rootfs" deb-systemd-helper is-enabled test.service 2>&1 | grep -qx "enabled"
test -L "$service_symlink"
test -f "$state_file"
grep -qx "/etc/systemd/system/multi-user.target.wants/test.service" "$state_file"

# test update-state with a change to the unit file
# add an alias to the unit file and check that it gets picked up by update-state

chroot "$rootfs" deb-systemd-helper is-enabled test.service 2>&1 | grep -qx "enabled"
echo "Alias=testalias.service" >> "$unit_file"
chroot "$rootfs" deb-systemd-helper update-state test.service
chroot "$rootfs" deb-systemd-helper reenable test.service
chroot "$rootfs" deb-systemd-helper is-enabled test.service 2>&1 | grep -qx "enabled"
grep -q "/etc/systemd/system/testalias.service" "$state_file"
test -f "$rootfs/var/lib/systemd/deb-systemd-helper-enabled/testalias.service"
