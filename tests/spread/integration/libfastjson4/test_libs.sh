#!/bin/bash
#spellchecker: ignore rootfs libfastjson

rootfs="$(install-slices libfastjson4_libs)"

# The multiarch directory and the dynamic loader's name differ per arch.
lib="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/libfastjson.so.4.*" -print -quit)"
loader="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/ld*.so.*" -print -quit)"
test -n "$lib"
test -n "$loader"

# The soname symlink points at the library.
test "$(readlink "$(dirname "$lib")/libfastjson.so.4")" = "$(basename "$lib")"

# Have the dynamic loader resolve every shared library libfastjson links
# against; it fails if any is missing.
output="$(chroot "$rootfs" "${loader#"$rootfs"}" --list "${lib#"$rootfs"}")"
echo "$output"
grep -Fq "libc.so.6" <<<"$output"
