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
  [systemd-sysv-install]="Usage:"
  [systemd-update-done]="unrecognized option"
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
# systemd-sulogin-shell hands the rescue and emergency shells to sulogin
chroot "$rootfs" /usr/sbin/sulogin --version | grep -Fq "util-linux"
umount "$rootfs/proc"
trap - EXIT
clean-rootfs "$rootfs"

# systemctl hands SysV init scripts to systemd-sysv-install, which drives
# update-rc.d with them
# TODO: cut only systemd_service-handlers here for future releases.
rootfs="$(install-slices systemd_service-handlers init-system-helpers_update-rc-d)"
# is-enabled sends its ls to /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
mount --bind /dev/null "$rootfs/dev/null"
trap 'umount "$rootfs/dev/null"' EXIT
mkdir -p "$rootfs/etc/init.d"
cat > "$rootfs/etc/init.d/chisel-test" <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          chisel-test
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
### END INIT INFO
EOF
chmod 755 "$rootfs/etc/init.d/chisel-test"

chroot "$rootfs" /usr/lib/systemd/systemd-sysv-install enable chisel-test
test -L "$rootfs/etc/rc2.d/S01chisel-test"
chroot "$rootfs" /usr/lib/systemd/systemd-sysv-install is-enabled chisel-test
chroot "$rootfs" /usr/lib/systemd/systemd-sysv-install disable chisel-test
test -L "$rootfs/etc/rc2.d/K01chisel-test"
if chroot "$rootfs" /usr/lib/systemd/systemd-sysv-install is-enabled chisel-test; then exit 1; fi
