#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

chroot "$ROOTFS" "$JAVA_HOME/bin/java" -Xlog:cds -Xshare:on -version
chroot "$ROOTFS" "$JAVA_HOME/bin/java" -Xlog:cds -Xshare:on -version 2>&1 | grep -q "Opened shared archive"
