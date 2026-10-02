#!/usr/bin/env bash
#spellchecker: ignore rootfs libperl cpan

rootfs=$(install-slices libperl5.42_scripts)

ls "$rootfs/usr/bin"
cpan=$(find "$rootfs/usr/bin" -type f -name 'cpan5.42*' | sed "s|$rootfs||")
test -n "$cpan"
chroot "$rootfs" "$cpan" --help 2>&1 | grep -q "Usage: cpan5.42"
