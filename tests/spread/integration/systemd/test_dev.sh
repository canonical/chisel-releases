#!/bin/bash
#spellchecker: ignore rootfs busctl cgls cgtop confext firstboot sysext sysinstall varlinkctl vpick nsrun nsystemctl logind

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# the slice on its own: every binary it ships answers --version
rootfs="$(install-slices systemd_dev)"
bins="$(chisel info --release "$PROJECT_PATH" systemd_dev | grep -oE '^ +/usr/bin/[^:]+' | tr -d ' ')"
test -n "$bins"
while read -r bin; do
  assert_version "$rootfs" "$bin"
done <<<"$bins"

# a couple that do real work without a running systemd
out="$(chroot "$rootfs" systemd-id128 new)"
grep -Eq "^[0-9a-f]{32}$" <<<"$out"
out="$(chroot "$rootfs" systemd-path system-binaries)"
grep -Fxq "/usr/bin" <<<"$out"
clean-rootfs "$rootfs"

# the rest are clients of a running manager, and of the bus it registers on
rootfs="$(install-slices systemd_dev dbus_services)"

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"

out="$(nsrun busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
  org.freedesktop.systemd1.Manager GetDefaultTarget)"
grep -Fq "graphical.target" <<<"$out"
out="$(nsrun varlinkctl call /run/systemd/io.systemd.Manager io.systemd.Manager.Describe '{}')"
grep -Fq '"Version"' <<<"$out"
nsrun systemd-cat -t chisel-test systemd-detect-virt --container
out="$(nsrun journalctl --no-pager -b -t chisel-test -o cat)"
grep -Fvq "none" <<<"$out"
out="$(nsrun systemd-cgls --no-pager)"
grep -Fq "systemd-journald" <<<"$out"
# the tree only shows up from the second sample on
out="$(nsrun systemd-cgtop -n2 -d 0.5 -b)"
grep -Fq "system.slice" <<<"$out"
out="$(nsrun systemd-id128 boot-id)"
grep -Eq "^[0-9a-f]{32}$" <<<"$out"
test "$(nsrun systemd-machine-id-setup --print)" = "$(nsrun systemd-id128 machine-id)"
out="$(nsrun systemd-delta --no-pager --diff=no)"
grep -Fq "ctrl-alt-del.target" <<<"$out"
out="$(nsrun systemd-mount --list --no-pager)"
grep -Fq "NODE" <<<"$out"
out="$(nsrun systemd-sysext list 2>&1)"
grep -Fq "No OS extensions" <<<"$out"
# spread keeps the rootfs on a tmpfs, where systemd will not keep a host key
out="$(echo secret | nsrun systemd-creds encrypt --with-key=null --name=chisel-test - - \
  | nsrun systemd-creds decrypt --with-key=null --allow-null --name=chisel-test - -)"
test "$out" = "secret"
nsystemctl start systemd-logind.service
# hold a lock and list the locks from inside it
out="$(nsrun systemd-inhibit --what=shutdown --who=chisel-test --why=test systemd-inhibit --list)"
grep -Fq "chisel-test" <<<"$out"

shutdown_rootfs
