#!/usr/bin/env bash
# spellchecker: ignore rootfs debianutils

rootfs="$(install-slices debianutils_run-parts)"
mkdir -p "$rootfs/test-run-parts"
echo -e '#!/bin/sh\necho "Hello from test script!"' > "$rootfs/test-run-parts/test-script"
chmod +x "$rootfs/test-run-parts/test-script"
chroot "$rootfs" run-parts --test /test-run-parts | grep "/test-run-parts/test-script"
