#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

chroot "$ROOTFS" "$JAVA_HOME/bin/java" /PrefsTest.java put
chroot "$ROOTFS" "$JAVA_HOME/bin/java" /PrefsTest.java get
