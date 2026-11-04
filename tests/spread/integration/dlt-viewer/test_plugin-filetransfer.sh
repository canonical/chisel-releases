source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices dlt-viewer_bins dlt-viewer_plugins)"
write_project "$rootfs/project.dlp" "Filetransfer Plugin"

# A string argument: type, little-endian length with the terminating nul, string.
str() {
  printf '\x00\x02\x00\x00'
  printf "\\x$(printf %02x $((${#1} + 1)))\\x00%s\\x00" "$1"
}

# A raw argument: type, little-endian length, bytes.
raw() {
  printf '\x00\x04\x00\x00'
  printf "\\x$(printf %02x ${#1})\\x00%s" "$1"
}

# Append a verbose info message from ECU1/FLTR/FILE holding the $1 arguments in args to the trace:
# storage header, standard header (extended header, ECU id, version 1) with the big-endian length
# of everything after the storage header, extended header.
append_message() {
  local len=$((18 + $(wc -c < "$rootfs/args")))
  {
    printf 'DLT\x01\x00\x00\x00\x00\x00\x00\x00\x00ECU1'
    printf "\\x25\\x00\\x00\\x$(printf %02x "$len")ECU1"
    printf "\\x41\\x$(printf %02x "$1")FLTRFILE"
    cat "$rootfs/args"
  } >> "$rootfs/trace.dlt"
}

# File 7, hello.txt, sent as 11 bytes in 2 packages of up to 6 bytes.
{ str FLST; str 7; str hello.txt; str 11; str "2026/10/09 00:00:00"; str 2; str 6; str FLST; } > "$rootfs/args"
append_message 8
{ str FLDA; str 7; str 1; raw "hello "; str FLDA; } > "$rootfs/args"
append_message 5
{ str FLDA; str 7; str 2; raw world; str FLDA; } > "$rootfs/args"
append_message 5
{ str FLFI; str 7; str FLFI; } > "$rootfs/args"
append_message 3

# The plugin reassembles the file from the trace and exports it.
if big_endian; then
  status=0
  chroot "$rootfs" dlt-viewer -s -p project.dlp -l trace.dlt -e "Filetransfer Plugin|export|/export" \
    2> "$rootfs/stderr" || status=$?
  test "$status" -eq 255
  grep -Fq "No filetransfer files in the loaded DLT file." "$rootfs/stderr"
else
  chroot "$rootfs" dlt-viewer -s -p project.dlp -l trace.dlt -e "Filetransfer Plugin|export|/export"
  test "$(cat "$rootfs/export/hello.txt")" = "hello world"
fi
