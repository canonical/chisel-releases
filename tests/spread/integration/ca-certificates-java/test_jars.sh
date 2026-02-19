#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices ca-certificates-java_jars openjdk-8-jre-headless_security)"

# mock /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

cd "$rootfs" || exit 1
chroot . /usr/sbin/update-ca-certificates
chroot . find /etc/ssl/certs/ -name *.pem -exec echo +{} \; > "$rootfs/certs"

# find java in the rootfs
java="$(find "$rootfs" -name java -type f -printf '/%P\n' -quit 2>/dev/null)"

# check we found a correct version
test -n "$java"
echo "$java" | grep -q '/usr/lib/jvm'

# mock /proc/self/exe
mkdir -p proc/self
ln -s "$java" proc/self/exe

chroot . "$java" -jar /usr/share/ca-certificates-java/ca-certificates-java.jar < certs
