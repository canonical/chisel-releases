#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

out="$(chroot "$ROOTFS" "$JAVA_HOME/bin/java" -cp . STCP 2>&1)" || true
if echo "$out" | grep -q "STREAM: 0: Test message"; then
  exit 0
fi
# Without SCTP in the kernel the socket call fails, which is past loading libsctp.
echo "$out" | grep -q "SocketException: Protocol not"
