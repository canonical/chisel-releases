#!/bin/bash
#spellchecker: ignore rootfs networkctl networkd

rootfs="$(install-slices systemd_network)"

bins=(
  /usr/bin/networkctl
  /usr/lib/systemd/systemd-network-generator
  /usr/lib/systemd/systemd-networkd
  /usr/lib/systemd/systemd-networkd-wait-online
)
for bin in "${bins[@]}"; do
  chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "systemd"
done
