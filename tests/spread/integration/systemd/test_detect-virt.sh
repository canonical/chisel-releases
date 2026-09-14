#!/bin/bash
#spellchecker: ignore rootfs virt

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

rootfs="$(install-slices systemd_detect-virt)"

out="$(chroot "$rootfs" systemd-detect-virt --help 2>&1)"

grep -Fiq "systemd-detect-virt" <<<"$out"
assert_version "$rootfs" systemd-detect-virt
out="$(chroot "$rootfs" systemd-detect-virt --list 2>&1)"
grep -Fiq "none" <<<"$out"
