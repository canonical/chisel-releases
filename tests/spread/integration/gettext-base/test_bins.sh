#!/bin/bash
#spellchecker: ignore rootfs ngettext envsubst

rootfs="$(install-slices gettext-base_bins)"

chroot "$rootfs" gettext "Hello World" | grep -q "Hello World"

chroot "$rootfs" ngettext "one item" "many items" 1 | grep -q "one item"
chroot "$rootfs" ngettext "one item" "many items" 2 | grep -q "many items"

printf 'Hello $TEST_VAR\n' | TEST_VAR=World \
    chroot "$rootfs" envsubst | grep -q "Hello World"

# a shell-format argument restricts substitution to the variables it names
printf 'Hello $TEST_VAR and $OTHER_VAR\n' | TEST_VAR=World OTHER_VAR=Nope \
    chroot "$rootfs" envsubst '$TEST_VAR' > /tmp/output
grep -q 'Hello World and \$OTHER_VAR' /tmp/output

chroot "$rootfs" envsubst -v '$TEST_VAR $OTHER_VAR' > /tmp/output
grep -qx "TEST_VAR" /tmp/output
grep -qx "OTHER_VAR" /tmp/output
