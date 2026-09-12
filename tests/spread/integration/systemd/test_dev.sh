#!/bin/bash
#spellchecker: ignore rootfs busctl cgls cgtop confext firstboot sysext sysinstall varlinkctl vpick nsrun nsystemctl logind

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# the slice on its own: every binary it ships answers --version
rootfs="$(install-slices systemd_dev)"
while read -r bin; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done < <(chisel info --release "$PROJECT_PATH" systemd_dev | grep -oE '^ +/usr/bin/[^:]+' | tr -d ' ')

# a couple that do real work without a running systemd
chroot "$rootfs" systemd-id128 new | grep -Eq "^[0-9a-f]{32}$"
chroot "$rootfs" systemd-path system-binaries | grep -Fxq "/usr/bin"
clean-rootfs "$rootfs"

# the rest are clients of a running manager, and of the bus it registers on
rootfs="$(install-slices systemd_dev dbus_services)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

nsrun busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager GetDefaultTarget | grep -Fq "graphical.target"
nsrun varlinkctl call /run/systemd/io.systemd.Manager io.systemd.Manager.Describe '{}' \
  | grep -Fq '"Version"'
nsrun systemd-cat -t chisel-test systemd-detect-virt --container
nsrun journalctl --no-pager -b -t chisel-test -o cat | grep -Fvq "none"
nsrun systemd-cgls --no-pager | grep -Fq "systemd-journald"
# the tree only shows up from the second sample on
nsrun systemd-cgtop -n2 -d 0.5 -b | grep -Fq "system.slice"
nsrun systemd-id128 boot-id | grep -Eq "^[0-9a-f]{32}$"
test "$(nsrun systemd-machine-id-setup --print)" = "$(nsrun systemd-id128 machine-id)"
nsrun systemd-delta --no-pager | grep -Fq "ctrl-alt-del.target"
nsrun systemd-mount --list --no-pager | grep -Fq "NODE"
nsrun systemd-sysext list 2>&1 | grep -Fq "No OS extensions"
echo secret | nsrun systemd-creds encrypt --name=chisel-test - - | nsrun systemd-creds decrypt --name=chisel-test - - \
  | grep -Fxq "secret"
nsystemctl start systemd-logind.service
# hold a lock and list the locks from inside it
nsrun systemd-inhibit --what=shutdown --who=chisel-test --why=test systemd-inhibit --list \
  | grep -Fq "chisel-test"

shutdown_rootfs
