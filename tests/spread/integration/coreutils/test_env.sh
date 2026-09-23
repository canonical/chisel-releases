#!/usr/bin/env bash
# spellchecker: ignore rootfs coreutils

rootfs="$(install-slices coreutils_env)"
chroot "$rootfs" env --version
test "$(chroot "$rootfs" env -i FOO=bar env)" = "FOO=bar"
