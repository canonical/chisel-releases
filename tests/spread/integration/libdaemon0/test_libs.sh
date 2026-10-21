#!/bin/bash
#spellchecker: ignore rootfs libdaemon

rootfs="$(install-slices libdaemon0_libs)"

# The multiarch directory and the dynamic loader's name differ per arch.
lib="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/libdaemon.so.0.*" -print -quit)"
loader="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/ld*.so.*" -print -quit)"
test -n "$lib"
test -n "$loader"

# The soname symlink points at the library.
test "$(readlink "$(dirname "$lib")/libdaemon.so.0")" = "$(basename "$lib")"

# Have the dynamic loader resolve every shared library libdaemon links
# against; it fails if any is missing.
output="$(chroot "$rootfs" "${loader#"$rootfs"}" --list "${lib#"$rootfs"}")"
echo "$output"
grep -Fq "libc.so.6" <<<"$output"
