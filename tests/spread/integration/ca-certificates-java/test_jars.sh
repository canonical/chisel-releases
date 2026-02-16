#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices ca-certificates-java_jars openjdk-8-jre-headless_security)"

# mock /dev/null
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

cd "$rootfs" || exit 1
chroot . /usr/sbin/update-ca-certificates
chroot . find /etc/ssl/certs/ -name *.pem -exec echo +{} \; > "$rootfs/certs"

mkdir -p proc/self
for java in $(find /usr/lib/jvm -name java -type f); do
  ln -s "/$java" proc/self/exe
  chroot . "/$java" -jar /usr/share/ca-certificates-java/ca-certificates-java.jar < certs
done
