#!/usr/bin/env bash

if [[ "$1" != "spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 

rootfs="$(install-slices cargo-1.84_bins)"
$SUDO chroot "${rootfs}/" cargo-1.84 --version | grep -q 'cargo 1.84'