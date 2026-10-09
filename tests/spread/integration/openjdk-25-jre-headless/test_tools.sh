#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

DNAME="CN=Sample Cert, OU=R&D, O=Company Ltd., L=Dublin 4, S=Dublin, C=IE"
chroot "$ROOTFS" "$JAVA_HOME/bin/keytool" -genkeypair -keystore foo -storepass barbar -keyalg RSA -dname "$DNAME"
