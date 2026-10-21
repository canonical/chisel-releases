#!/bin/bash
#spellchecker: ignore rootfs kmod quotaon modprobe plymouth udevadm initrd fstab

# Every systemd slice that ships units also ships the programs they run, so a
# unit started from any of them does not fail with 203/EXEC. Each slice is cut
# with minimal, since a unit needs a manager to run it.

# Programs from packages systemd does not depend on. Each sits behind a
# condition, a "-" prefix or an opt-in, so a rootfs without it boots the same.
elsewhere=(
  /usr/bin/bash      # debug-shell and the breakpoint units, kernel command line opt-ins
  /usr/bin/kmod      # kmod-static-nodes, ConditionPathExists= on it
  /usr/sbin/quotaon  # quotaon units, pulled in by quota options in fstab only
  modprobe           # modprobe@, "-" prefixed
  plymouth           # "-" prefixed ExecStartPre= of rescue, emergency and the breakpoints
  systemd-dissect    # systemd-loop@, started through the API only
  udevadm            # initrd-udevadm-cleanup-db, initrd only
)

programs_seen=0

# fail on any program a unit file in the rootfs runs that the rootfs lacks
assert_unit_programs() {
  local rootfs="$1"
  local runs missing="" file program path link
  local -a candidates
  runs="$(grep -rsHE '^Exec(Condition|Start|StartPre|StartPost|Reload|Stop|StopPost)=' \
      "$rootfs"/usr/lib/systemd/system "$rootfs"/usr/lib/systemd/user \
      "$rootfs"/etc/systemd/system "$rootfs"/etc/systemd/user \
    | sed -E "s#^$rootfs##; s#:Exec[A-Za-z]*=[-@:+!|]*# #" \
    | awk '$2 != "" && $2 !~ /[%$]/ {print $1, $2}' | sort -u || true)"
  [ -n "$runs" ] || return 0
  while read -r file program; do
    programs_seen=$((programs_seen + 1))
    [[ " ${elsewhere[*]} " == *" $program "* ]] && continue
    if [[ "$program" == /* ]]; then
      candidates=("$program")
    else
      # bare names resolve against the manager's fixed search path
      candidates=(/usr/local/sbin/"$program" /usr/local/bin/"$program" /usr/sbin/"$program" /usr/bin/"$program")
    fi
    for path in "${candidates[@]}"; do
      # follow links inside the rootfs rather than on the host
      for _ in 1 2 3 4 5 6 7 8; do
        link="$(readlink "$rootfs$path")" || break
        case "$link" in
          /*) path="$link" ;;
          *) path="$(dirname "$path")/$link" ;;
        esac
      done
      [ -e "$rootfs$path" ] && continue 2
    done
    missing+="$file: $program"$'\n'
  done <<<"$runs"
  if [ -n "$missing" ]; then
    printf 'units run programs the rootfs lacks:\n%s' "$missing" >&2
    return 1
  fi
}

# every slice that ships a system or user unit, so a new one is covered too
slices="$(chisel info --release "$PROJECT_PATH" systemd \
  | awk '/^    [a-z0-9-]+:$/ {slice = $1; sub(":", "", slice)}
         /^ +\/usr\/lib\/systemd\/(system|user)\// {print slice}' | sort -u)"
test -n "$slices"

for slice in $slices; do
  rootfs="$(install-slices "systemd_$slice" systemd_minimal)"
  assert_unit_programs "$rootfs"
  clean-rootfs "$rootfs"
done

# and the scan found units to check at all
test "$programs_seen" -gt 0
