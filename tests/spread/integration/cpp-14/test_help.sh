#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs libexec

arch=$(uname -m)-linux-gnu
rootfs="$(install-slices \
    base-files_bin \
    cpp-14-"${arch//_/-/}"_cc1 \
)"
ln -s "/usr/libexec/gcc/$arch/14/cc1" "${rootfs}/usr/bin/cc1"

(chroot "${rootfs}" cc1 --help || true) | grep -q "The following options are language-independent:"