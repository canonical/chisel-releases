source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices dlt-viewer_bins dlt-viewer_plugins)"
write_project "$rootfs/project.dlp" "DLT DBus Plugin"

# A D-Bus 32-bit integer, little-endian.
u32() {
  printf "\\x$1\\x00\\x00\\x00"
}

{
  # Storage header: magic, seconds, microseconds, ECU id.
  printf 'DLT\x01\x00\x00\x00\x00\x00\x00\x00\x00ECU1'
  # Standard header: flags (extended header, ECU id, version 1), counter, big-endian length of
  # everything after the storage header, ECU id.
  printf '\x25\x00\x00\x5eECU1'
  # Extended header: verbose IPC network trace, 2 arguments, application id, context id.
  printf '\x15\x02DBUSALL\x00'
  # Raw argument with the D-Bus fixed header: byte order, method call, no flags, version 1,
  # body length 0, serial 1, header fields length 48.
  printf '\x00\x04\x00\x00\x10\x00l\x01\x00\x01'
  u32 00
  u32 01
  u32 30
  # Raw argument with the header fields, each padded to 8 bytes: path /t, member Ping and
  # interface org.t.I.
  printf '\x00\x04\x00\x00\x30\x00'
  printf '\x01\x01o\x00'
  u32 02
  printf '/t\x00\x00\x00\x00\x00\x00'
  printf '\x03\x01s\x00'
  u32 04
  printf 'Ping\x00\x00\x00\x00'
  printf '\x02\x01s\x00'
  u32 07
  printf 'org.t.I\x00'
} > "$rootfs/trace.dlt"

# The plugin decodes the method call: type, sender and serial, path, interface and member, and
# the empty body.
chroot "$rootfs" dlt-viewer -s -p project.dlp -c trace.dlt trace.txt 2> "$rootfs/stderr"
cat "$rootfs/trace.txt"
if big_endian; then
  grep -Fq 'Enable "DLT DBus Plugin"' "$rootfs/stderr"
  test -f "$rootfs/trace.txt"
  test ! -s "$rootfs/trace.txt"
else
  grep -Fq "C [,1]  /t org.t.I.Ping  ()" "$rootfs/trace.txt"
fi
