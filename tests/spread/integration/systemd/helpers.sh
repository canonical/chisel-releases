#!/bin/bash
#spellchecker: ignore rootfs nsenter nsrun nsystemctl getty uts

# Boots a chiselled rootfs with systemd as PID 1 of nested pid, mount, uts and
# network namespaces, so the slice under test is what PID 1 sees and what its
# daemons change stays in there. The mounts made here live under $ROOTFS_DIR
# and are swept by clean-rootfs.

boot_rootfs() {
  local rootfs="$1"

  mkdir -p "$rootfs"/{proc,sys,dev,run,tmp}
  # generators pivot into the root and PID 1 gets moved onto /: it has to be
  # a mount point
  mount --bind "$rootfs" "$rootfs"
  mount --make-private "$rootfs"
  mount -t tmpfs tmpfs "$rootfs/run"
  mount -t tmpfs tmpfs "$rootfs/tmp"
  mount --rbind /dev "$rootfs/dev"
  # /dev is shared: without this, unmounting the copies later unmounts the
  # container's own device nodes
  mount --make-rprivate "$rootfs"

  # no tty in here; the runtime mask stays out of the cut
  mkdir -p "$rootfs/run/systemd/system"
  ln -s /dev/null "$rootfs/run/systemd/system/console-getty.service"

  # systemd mounts /sys and the cgroup tree itself; /proc has to be the one
  # of the new pid namespace, so unshare mounts it rather than us.
  # onto / rather than a chroot: setns() back into this namespace resets root
  # to its /, and machine-id-commit reads the id back through that
  env -i container=lxc SYSTEMD_LOG_TARGET=console \
    unshare --pid --uts --net --fork --mount-proc="$rootfs/proc" \
    sh -c 'cd "$1" && mount --move . / && exec chroot . /usr/lib/systemd/systemd' sh "$rootfs" &
  unshare_pid=$!

  systemd_pid=""
  for _ in $(seq 1 100); do
    systemd_pid="$(pgrep -P "$unshare_pid" || true)"
    [ -n "$systemd_pid" ] && break
    sleep 0.1
  done
  test -n "$systemd_pid"

  local state=""
  for _ in $(seq 1 60); do
    state="$(nsystemctl is-system-running 2>/dev/null || true)"
    case "$state" in
      running|degraded) return 0 ;;
    esac
    sleep 0.5
  done
  echo "systemd did not finish booting: $state" >&2
  nsystemctl --failed --no-legend >&2 || true
  return 1
}

# run a command inside the booted rootfs
nsrun() {
  nsenter -t "$systemd_pid" -m -p -u -n -r -w "$@"
}

nsystemctl() {
  nsrun systemctl "$@"
}

# a binary in the rootfs runs and prints systemd's version banner; stderr stays
# out of the pipe, since loader and chroot errors name systemd too
assert_version() {
  chroot "$1" "$2" --version | grep -Eq '^systemd [0-9]+ '
}

# fail on any failed unit other than the ones named; the container cannot
# mount kernel file systems, so those two are expected under standard
assert_failed_units() {
  local unexpected
  unexpected="$(comm -23 \
    <(nsystemctl --failed --no-legend --plain | awk '{print $1}' | sort) \
    <(printf '%s\n' "$@" | sort))"
  if [ -n "$unexpected" ]; then
    echo "unexpected failed units: $unexpected" >&2
    nsystemctl --failed --no-legend >&2
    return 1
  fi
}

shutdown_rootfs() {
  # without logind, systemctl complains about the bus and then asks PID 1
  # directly; the exit of the namespace is what we check
  nsystemctl poweroff 2>/dev/null || true
  for _ in $(seq 1 40); do
    kill -0 "$unshare_pid" 2>/dev/null || return 0
    sleep 0.5
  done
  echo "systemd did not exit after poweroff" >&2
  # killing PID 1 of the namespace takes everything in it down
  kill -KILL "$systemd_pid" 2>/dev/null || true
  return 1
}
