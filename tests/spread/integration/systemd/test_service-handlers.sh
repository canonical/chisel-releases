#!/bin/bash
#spellchecker: ignore rootfs pstore quotacheck rfkill sulogin sysroot fstab xdg

rootfs="$(install-slices systemd_service-handlers)"

# some tools refuse to run without /proc
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

# most answer --version; these take none and reject the argument instead,
# which still proves they load
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

# every handler the slice itself ships
while read -r bin; do
  name="${bin##*/}"
  case "$name" in
    systemd-quotacheck)
      # says nothing, must not fail
      chroot "$rootfs" "$bin" --version
      ;;
    systemd-sulogin-shell)
      # treats its argument as a mode and then waits for a login
      timeout 5 chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "journalctl -xb"
      ;;
    *)
      chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "${usage[$name]:-systemd}"
      ;;
  esac
done < <(chisel info --release "$PROJECT_PATH" systemd_service-handlers | grep -oE '^ +/usr/lib/systemd/[^:]+' | tr -d ' ')
