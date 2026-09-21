#!/bin/bash
#spellchecker: ignore rootfs pstore quotacheck rfkill sulogin sysroot fstab xdg rslave

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
bins="$(chisel info --release "$PROJECT_PATH" systemd_service-handlers | grep -oE '^ +/usr/lib/systemd/[^:]+' | tr -d ' ')"
test -n "$bins"
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
      if [ -n "${usage[$name]:-}" ]; then
        chroot "$rootfs" "$bin" --version 2>&1 | grep -Fiq "${usage[$name]}"
      else
        chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
      fi
      ;;
  esac
done <<<"$bins"

# the rescue and emergency shells: sulogin, with a locked root forced through,
# falls back to /bin/sh since root's shell is not in here. It flushes the
# terminal before it prompts, so keep typing until a shell answers.
mkdir -p "$rootfs/dev"
mount --rbind /dev "$rootfs/dev"
mount --make-rslave "$rootfs/dev"
trap 'umount -R "$rootfs/dev"; umount "$rootfs/proc"' EXIT
echo 'root:x:0:0:root:/root:/bin/bash' > "$rootfs/etc/passwd"
echo 'root:*:19000:0:99999:7:::' > "$rootfs/etc/shadow"
out="$(
  { for _ in $(seq 1 15); do sleep 1; printf '\necho rescue-shell-$((6 * 7))\n'; done; printf 'exit\n'; } \
    | timeout 60 script -qec "chroot $rootfs /usr/sbin/sulogin --force" /dev/null
)"
grep -Fq "rescue-shell-42" <<<"$out"
