#!/bin/bash
#spellchecker: ignore rootfs ngettext envsubst

rootfs="$(install-slices gettext-base_bins)"

chroot "$rootfs" gettext "Hello World" | grep -q "Hello World"

chroot "$rootfs" ngettext "one item" "many items" 1 | grep -q "one item"
chroot "$rootfs" ngettext "one item" "many items" 2 | grep -q "many items"

printf 'Hello $TEST_VAR\n' | TEST_VAR=World \
    chroot "$rootfs" envsubst | grep -q "Hello World"
