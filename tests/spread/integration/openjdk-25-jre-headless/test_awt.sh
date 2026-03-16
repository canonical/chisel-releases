#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

export XDG_CACHE_HOME=/tmp
chroot "$ROOTFS" "$JAVA_HOME/bin/java" /ImageTest.java
file -i "$ROOTFS/HelloWorld.png" | grep -q "image/png; charset=binary"
