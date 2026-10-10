source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices dlt-viewer_bins)"
write_trace "$rootfs/trace.dlt"

chroot "$rootfs" dlt-viewer --version
chroot "$rootfs" dlt-parser --help
chroot "$rootfs" dlt-commander --version

# Convert the trace to text without a display.
chroot "$rootfs" dlt-viewer -s -t -c trace.txt trace.dlt
cat "$rootfs/trace.txt"
if big_endian; then
  test -f "$rootfs/trace.txt"
  test ! -s "$rootfs/trace.txt"
else
  grep -Fq "ECU1 APP1 CTX1 0 log info verbose 1 hello chisel" "$rootfs/trace.txt"
fi
