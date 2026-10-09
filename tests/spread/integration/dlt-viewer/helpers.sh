# Qt needs no display with the offscreen platform plugin.
export QT_QPA_PLATFORM=offscreen

# Write a DLT trace holding one verbose info message from ECU1/APP1/CTX1 with the string
# argument "hello chisel".
write_trace() {
  {
    # Storage header: magic, seconds, microseconds, ECU id.
    printf 'DLT\x01\x00\x00\x00\x00\x00\x00\x00\x00ECU1'
    # Standard header: flags (extended header, ECU id, version 1), counter, big-endian length
    # of everything after the storage header, ECU id.
    printf '\x25\x00\x00\x25ECU1'
    # Extended header: verbose info log message, 1 argument, application id, context id.
    printf '\x41\x01APP1CTX1'
    # Argument: string type, little-endian length with the terminating nul, string.
    printf '\x00\x02\x00\x00\x0d\x00hello chisel\x00'
  } > "$1"
}
