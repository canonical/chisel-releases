#!/bin/bash
#spellchecker: ignore rootfs virt

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

rootfs="$(install-slices systemd_detect-virt)"

chroot "$rootfs" systemd-detect-virt --help | grep -Fiq "systemd-detect-virt"
assert_version "$rootfs" systemd-detect-virt
chroot "$rootfs" systemd-detect-virt --list | grep -Fiq "none"
