source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices dlt-viewer_bins dlt-viewer_plugins)"
write_project "$rootfs/project.dlp" "DLT Segmentation Plugin"

# Write the headers of a DLT version 2 verbose info message from ECU1/APP1/CTX1 with 1 argument:
# storage header, header type (version 2, ECU id, application and context ids, segmentation),
# counter $1, big-endian length $2 of everything after the storage header, message info, argument
# count, zero timestamp, length-prefixed ids.
frame() {
  printf 'DLT\x01\x00\x00\x00\x00\x00\x00\x00\x00ECU1'
  printf '\x4c\x08\x00\x00'"$1$2"'\x41\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00'
  printf '\x04ECU1\x04APP1\x04CTX1'
}

# The string argument "hello chisel" split over three frames.
{
  # First frame: the big-endian total length 19 of the argument, then its first 7 bytes.
  frame '\x00' '\x00\x32'
  printf '\x09\x00\x00\x00\x00\x00\x00\x00\x00\x13'
  printf '\x00\x02\x00\x00\x0d\x00h'
  # Consecutive frame 0.
  frame '\x01' '\x00\x2d'
  printf '\x05\x01\x00\x00\x00\x00'
  printf 'ello c'
  # Last frame.
  frame '\x02' '\x00\x29'
  printf '\x01\x02'
  printf 'hisel\x00'
} > "$rootfs/trace.dlt"

# The plugin reassembles the argument in the last frame.
chroot "$rootfs" dlt-viewer -s -p project.dlp -c trace.dlt trace.txt 2> "$rootfs/stderr"
cat "$rootfs/trace.txt"
if big_endian; then
  grep -Fq 'Enable "DLT Segmentation Plugin"' "$rootfs/stderr"
  test -f "$rootfs/trace.txt"
  test ! -s "$rootfs/trace.txt"
else
  grep -Fq "2 ECU1 APP1 CTX1 0 log info verbose 1 hello chisel" "$rootfs/trace.txt"
fi
