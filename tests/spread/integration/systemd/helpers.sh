#!/bin/bash
#spellchecker: ignore rootfs nsenter nsrun nsystemctl getty uts kmod quotaon modprobe plymouth udevadm initrd fstab

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
    systemd_pid="$(pgrep -P "$unshare_pid"  -x "systemd"|| true)"
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

# whether a path exists inside the rootfs, following an absolute link in there
# rather than on the host
exists_in_rootfs() {
  local rootfs="$1" path="$2" link
  for _ in 1 2 3 4 5 6 7 8; do
    link="$(readlink "$rootfs$path")" || { [ -e "$rootfs$path" ]; return; }
    case "$link" in
      /*) path="$link" ;;
      *) path="$(dirname "$path")/$link" ;;
    esac
  done
  return 1
}

# Programs systemd units run that come from packages systemd does not depend
# on. Each sits behind a condition, a "-" prefix or an opt-in, so a rootfs
# without it boots the same.
UNIT_PROGRAMS_ELSEWHERE=(
  /usr/bin/bash      # debug-shell and the breakpoint units, kernel command line opt-ins
  /usr/bin/kmod      # kmod-static-nodes, ConditionPathExists= on it
  /usr/sbin/quotaon  # quotaon units, pulled in by quota options in fstab only
  modprobe           # modprobe@, "-" prefixed
  plymouth           # "-" prefixed ExecStartPre= of rescue, emergency and the breakpoints
  systemd-dissect    # systemd-loop@, started through the API only
  udevadm            # initrd-udevadm-cleanup-db, initrd only
)

# fail on any program a unit file in the rootfs runs that the rootfs lacks,
# other than the ones above and the ones named
assert_unit_programs() {
  local rootfs="$1"
  shift
  local allowed=" ${UNIT_PROGRAMS_ELSEWHERE[*]} $* "
  local runs missing="" file program dir
  runs="$(grep -rsHE '^Exec(Condition|Start|StartPre|StartPost|Reload|Stop|StopPost)=' \
      "$rootfs"/usr/lib/systemd/system "$rootfs"/usr/lib/systemd/user \
      "$rootfs"/etc/systemd/system "$rootfs"/etc/systemd/user \
    | sed -E "s#^$rootfs##; s#:Exec[A-Za-z]*=[-@:+!|]*# #" \
    | awk '$2 != "" && $2 !~ /[%$]/ {print $1, $2}' | sort -u || true)"
  if [ -z "$runs" ]; then
    echo "no unit in $rootfs runs anything" >&2
    return 1
  fi
  while read -r file program; do
    [[ "$allowed" == *" $program "* ]] && continue
    if [[ "$program" == /* ]]; then
      exists_in_rootfs "$rootfs" "$program" && continue
    else
      # bare names resolve against the manager's fixed search path
      for dir in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin; do
        exists_in_rootfs "$rootfs" "$dir/$program" && continue 2
      done
    fi
    missing+="$file: $program"$'\n'
  done <<<"$runs"
  if [ -n "$missing" ]; then
    printf 'units run programs the rootfs lacks:\n%s' "$missing" >&2
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
