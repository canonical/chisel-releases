#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

chroot "$ROOTFS" "$JAVA_HOME/bin/java" /ReadCertificate.java

# NSS seeds itself from the random device
mkdir -p "$ROOTFS/dev"
touch "$ROOTFS/dev/urandom"
mount --bind /dev/urandom "$ROOTFS/dev/urandom"
trap 'umount "$ROOTFS/dev/urandom"' EXIT
out="$(chroot "$ROOTFS" "$JAVA_HOME/bin/java" /NssProvider.java /etc/java-25-openjdk/security/nss.cfg)"
test "$out" = "provider: SunPKCS11-NSS"
