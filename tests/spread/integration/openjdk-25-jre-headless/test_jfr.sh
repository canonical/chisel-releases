#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

chroot "$ROOTFS" "$JAVA_HOME/bin/java" -XX:+FlightRecorder -XX:StartFlightRecording=duration=60s,filename=dump.jfr /Main.java

test -f "$ROOTFS/dump.jfr" || (echo "JFR dump file $ROOTFS/dump.jfr not found!" ; exit 1)
