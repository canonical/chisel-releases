#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices libdbd-mysql-perl_libs)"

# The multiarch directory and the dynamic loader's name differ per arch.
loader="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/ld*.so.*" -print -quit)"
lib="$(find "$rootfs" -path "*/lib/*-linux-*/perl5/*/auto/DBD/mysql/mysql.so" -print -quit)"
test -n "$loader"
test -n "$lib"

# Have the dynamic loader resolve every shared library the perl module links
# against; it fails if any is missing.
output="$(chroot "$rootfs" "${loader#"$rootfs"}" --list "${lib#"$rootfs"}")"
echo "$output"
echo "$output" | grep -Fq "libmysqlclient.so.24"
