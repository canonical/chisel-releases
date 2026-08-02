#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

chroot "$ROOTFS" "$JAVA_HOME/bin/java" \
    -Dcom.sun.management.jmxremote.port=5000 \
    -Dcom.sun.management.jmxremote.authenticate=false \
    -Dcom.sun.management.jmxremote=true \
    -Dcom.sun.management.jmxremote.ssl=false -cp . TestJMX
