#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 

rootfs="$(install-slices cargo-1.84_cargo)"
ln -s cargo-1.84 "${rootfs}"/usr/bin/cargo

chroot "${rootfs}/" cargo --help | grep -q "Rust's package manager"
chroot "${rootfs}/" cargo --version | grep -q 'cargo 1.84'
