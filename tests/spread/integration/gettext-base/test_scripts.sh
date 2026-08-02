#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices gettext-base_scripts)"

test -x "$rootfs/usr/bin/gettext.sh"

# gettext.sh can be sourced and provides eval_gettext and eval_ngettext
c='. /usr/bin/gettext.sh && eval_gettext "Hello World"'
chroot "$rootfs" sh -c "$c" | grep -q "Hello World"
c='. /usr/bin/gettext.sh && eval_ngettext "one item" "many items" 1'
chroot "$rootfs" sh -c "$c" | grep -q "one item"
c='. /usr/bin/gettext.sh && eval_ngettext "one item" "many items" 2'
chroot "$rootfs" sh -c "$c" | grep -q "many items"

# eval_gettext expands shell variables in the message it is handed
c='. /usr/bin/gettext.sh && name=World && eval_gettext "Hello \$name"'
chroot "$rootfs" sh -c "$c" | grep -q "Hello World"
