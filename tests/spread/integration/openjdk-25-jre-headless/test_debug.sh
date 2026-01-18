#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

chroot "$ROOTFS" "$JAVA_HOME/bin/java" -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005 /Main.java
