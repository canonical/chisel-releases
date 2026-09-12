#!/bin/bash
#spellchecker: ignore rootfs hostnamectl localectl timedatectl loginctl

rootfs="$(install-slices \
  systemd_hostname \
  systemd_locale \
  systemd_login \
  systemd_timedate)"

commands=(
  hostnamectl
  localectl
  timedatectl
  loginctl
)

for command in "${commands[@]}"; do
  chroot "$rootfs" "/usr/bin/$command" --help 2>&1 | grep -Fiq "$command"
  chroot "$rootfs" "/usr/bin/$command" --version 2>&1 | grep -Fiq "systemd"
done
