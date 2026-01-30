#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

# /usr/lib/jvm/java-25-openjdk-*/bin/javac:
chroot "$ROOTFS" "$JAVA_HOME/bin/javac" /Main.java -d /
# /usr/lib/jvm/java-25-openjdk-*/bin/javadoc:
chroot "$ROOTFS" "$JAVA_HOME/bin/javadoc" /Main.java
# /usr/lib/jvm/java-25-openjdk-*/bin/javap:
chroot "$ROOTFS" "$JAVA_HOME/bin/javap" -l /Main.class
# /usr/lib/jvm/java-25-openjdk-*/bin/jdeprscan:
chroot "$ROOTFS" "$JAVA_HOME/bin/jdeprscan" --class-path . Main
# /usr/lib/jvm/java-25-openjdk-*/bin/jdeps:
chroot "$ROOTFS" "$JAVA_HOME/bin/jdeps" -m java.base
# /usr/lib/jvm/java-25-openjdk-*/bin/jimage:
chroot "$ROOTFS" "$JAVA_HOME/bin/jimage" info "$JAVA_HOME/lib/modules"
# /usr/lib/jvm/java-25-openjdk-*/bin/serialver:
chroot "$ROOTFS" "$JAVA_HOME/bin/serialver" -classpath / SerializableObject
