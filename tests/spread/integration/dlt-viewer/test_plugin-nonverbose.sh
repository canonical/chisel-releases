source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices dlt-viewer_bins dlt-viewer_plugins)"

# A FIBEX description of message id 1: an info log message from APP1/CTX1 with one uint16.
cat > "$rootfs/fibex.xml" <<EOF
<FIBEX><ELEMENTS>
  <PDUS>
    <PDU ID="PDU_U16"><BYTE-LENGTH>2</BYTE-LENGTH><SIGNAL-INSTANCE><SIGNAL-REF ID-REF="S_UINT16"/></SIGNAL-INSTANCE></PDU>
  </PDUS>
  <FRAMES>
    <FRAME ID="ID_1">
      <BYTE-LENGTH>2</BYTE-LENGTH>
      <MESSAGE_TYPE>DLT_TYPE_LOG</MESSAGE_TYPE><MESSAGE_INFO>DLT_LOG_INFO</MESSAGE_INFO>
      <APPLICATION_ID>APP1</APPLICATION_ID><CONTEXT_ID>CTX1</CONTEXT_ID>
      <PDU-REF ID-REF="PDU_U16"/>
    </FRAME>
  </FRAMES>
</ELEMENTS></FIBEX>
EOF
write_project "$rootfs/project.dlp" "Non Verbose Mode Plugin" /fibex.xml

{
  # Storage header: magic, seconds, microseconds, ECU id.
  printf 'DLT\x01\x00\x00\x00\x00\x00\x00\x00\x00ECU1'
  # Standard header: flags (ECU id, version 1, no extended header, so non-verbose), counter,
  # big-endian length of everything after the storage header, ECU id.
  printf '\x24\x00\x00\x0eECU1'
  # Payload: little-endian message id 1, then the uint16 0x1234.
  printf '\x01\x00\x00\x00\x34\x12'
} > "$rootfs/trace.dlt"

# The plugin decodes the payload as described in the FIBEX file.
chroot "$rootfs" dlt-viewer -s -t -c trace.txt project.dlp trace.dlt 2> "$rootfs/stderr"
cat "$rootfs/trace.txt"
if big_endian; then
  grep -Fq "Finish loading Fibex XML." "$rootfs/stderr"
  test -f "$rootfs/trace.txt"
  test ! -s "$rootfs/trace.txt"
else
  grep -Fq "ECU1 APP1 CTX1 0 log info non-verbose 1 4660" "$rootfs/trace.txt"
fi
