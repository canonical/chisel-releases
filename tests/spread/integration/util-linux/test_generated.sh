#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices util-linux_generated)"

test -e "$rootfs"/usr/bin/pager
