#!/usr/bin/env bash
#spellchecker: ignore rootfs libperl

rootfs=$(install-slices libperl5.42_bins)

ls "$rootfs/usr/bin"
perl=$(find "$rootfs/usr/bin" -type f -name 'perl5.42*' | sed "s|$rootfs||")

# mock /dev/null
mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"

test -n "$perl"
chroot "$rootfs" "$perl" --version | grep -q "This is perl 5, version 42, subversion 3 (v5.42.3)"
chroot "$rootfs" "$perl" --help | grep -q "Usage: /usr/bin/perl5.42"

# test hello world
chroot "$rootfs" "$perl" -e 'print "hello from perl\n";' | grep -q "hello from perl"

# test importing a module that is not included in the slice
chroot "$rootfs" "$perl" -e 'use constant FOO => 42;' 2>&1 | grep -q "Can't locate constant.pm in @INC"

# retry with the module included
rootfs=$(install-slices libperl5.42_bins perl-modules-5.42_core)
mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"
chroot "$rootfs" "$perl" -e 'use constant FOO => 42; print FOO;' | grep -q "42"
