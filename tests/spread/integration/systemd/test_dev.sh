#!/bin/bash
#spellchecker: ignore rootfs busctl cgls cgtop confext firstboot sysext sysinstall varlinkctl vpick

rootfs="$(install-slices systemd_dev)"

bins=(
  busctl
  systemd-ac-power
  systemd-ask-password
  systemd-cat
  systemd-cgls
  systemd-cgtop
  systemd-confext
  systemd-creds
  systemd-delta
  systemd-firstboot
  systemd-id128
  systemd-inhibit
  systemd-machine-id-setup
  systemd-mount
  systemd-path
  systemd-socket-activate
  systemd-stdio-bridge
  systemd-sysext
  systemd-sysinstall
  systemd-tty-ask-password-agent
  systemd-umount
  systemd-vpick
  varlinkctl
)
for bin in "${bins[@]}"; do
  chroot "$rootfs" "/usr/bin/$bin" --version 2>&1 | grep -Fiq "systemd"
done

# a couple that do real work without a running systemd
chroot "$rootfs" systemd-id128 new | grep -Eq "^[0-9a-f]{32}$"
chroot "$rootfs" systemd-path system-binaries | grep -Fxq "/usr/bin"
