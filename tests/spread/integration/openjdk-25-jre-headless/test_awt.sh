#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

export XDG_CACHE_HOME=/tmp
chroot "$ROOTFS" "$JAVA_HOME/bin/java" /ImageTest.java
test "$(head -c 8 "$ROOTFS/HelloWorld.png" | od -An -tx1 | tr -d ' \n')" = 89504e470d0a1a0a
