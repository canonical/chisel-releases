#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

export XDG_CACHE_HOME=/tmp
chroot "$ROOTFS" "$JAVA_HOME/bin/java" /ImageTest.java
file -i "$ROOTFS/HelloWorld.png" | grep -q "image/png; charset=binary"
chroot "$ROOTFS" "$JAVA_HOME/bin/java" -Djava.net.useSystemProxies=true -cp / ProxyTest
# the trimmed font stack leaves out gio, brotli's encoder and libexpatw
test -z "$(find "$ROOTFS" -name 'libgio-2.0.so*' -o -name 'libbrotlienc.so*' -o -name 'libexpatw.so*')"
