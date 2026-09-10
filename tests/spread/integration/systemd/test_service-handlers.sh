#!/bin/bash
#spellchecker: ignore rootfs binfmt bsod growfs pstore quotacheck rfkill storagetm sulogin sysctl sysroot fstab validatefs xdg

rootfs="$(install-slices systemd_service-handlers)"

# some tools refuse to run without /proc
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

bins=(
  systemd-battery-check
  systemd-binfmt
  systemd-boot-check-no-failures
  systemd-bsod
  systemd-factory-reset
  systemd-growfs
  systemd-hibernate-resume
  systemd-random-seed
  systemd-sleep
  systemd-socket-proxyd
  systemd-ssh-issue
  systemd-storagetm
  systemd-sysctl
  systemd-update-done
  systemd-validatefs
)
for bin in "${bins[@]}"; do
  chroot "$rootfs" "/usr/lib/systemd/$bin" --version 2>&1 | grep -Fiq "systemd"
done

# these take no --version; each still has to load and reject the argument
declare -A usage=(
  [systemd-backlight]="Unknown command verb"
  [systemd-fsck]="Failed to stat"
  [systemd-makefs]="expects two arguments"
  [systemd-pstore]="takes zero or two arguments"
  [systemd-remount-fs]="takes no arguments"
  [systemd-reply-password]="Wrong number of arguments"
  [systemd-rfkill]="requires no arguments"
  [systemd-ssh-proxy]="Expected two arguments"
  [systemd-sysroot-fstab-check]="takes no arguments"
  [systemd-volatile-root]="Couldn't parse volatile mode"
  [systemd-xdg-autostart-condition]="Wrong argument count"
)
for bin in "${!usage[@]}"; do
  chroot "$rootfs" "/usr/lib/systemd/$bin" --version 2>&1 | grep -Fiq "${usage[$bin]}"
done

chroot "$rootfs" /usr/lib/systemd/systemd-quotacheck --version

# the rescue shell treats its argument as a mode and then waits for a login
timeout 5 chroot "$rootfs" /usr/lib/systemd/systemd-sulogin-shell --version 2>&1 \
  | grep -Fiq "journalctl -xb"
