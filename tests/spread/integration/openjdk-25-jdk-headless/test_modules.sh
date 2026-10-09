#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

output=$(basename $(mktemp -u))
chroot "$ROOTFS" "$JAVA_HOME/bin/jlink" --add-modules java.base --output "$output"
rm -rf "$ROOTFS/$output"
chroot "$ROOTFS" "$JAVA_HOME/bin/jmod" list "$JAVA_HOME/jmods/java.rmi.jmod"
