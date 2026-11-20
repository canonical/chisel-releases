#!/bin/bash
#spellchecker: ignore rootfs dpkg

# the library is sourced by the dpkg scripts, so bring a shell to source it with
rootfs="$(install-slices dpkg_sh-lib dash_bins base-files_bin)"

out="$(chroot "$rootfs" sh -c '. /usr/share/dpkg/sh/dpkg-error.sh; warning "careful"' 2>&1)"
grep -qx "sh: warning: careful" <<<"$out"

# error() reports and exits 1
rc=0
out="$(chroot "$rootfs" sh -c '. /usr/share/dpkg/sh/dpkg-error.sh; error "boom"; echo unreachable' 2>&1)" || rc=$?
test "$rc" -eq 1
grep -qx "sh: error: boom" <<<"$out"
