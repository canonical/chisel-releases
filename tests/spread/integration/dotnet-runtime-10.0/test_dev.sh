#!/bin/bash
#spellchecker: ignore rootfs createdump tracept mscordaccore mscordbi

# What a consumer gets from dotnet-runtime-10.0_dev: standard and every
# add-on slice at once.

# shellcheck source=tests/spread/integration/dotnet-runtime-10.0/helpers.sh
. ./helpers.sh

rootfs="$(probe_rootfs dotnet-runtime-10.0_dev)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll culture | grep -Fxq "culture: ok 1.234,5"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll negotiate | grep -q "^negotiate: ok "
if is_coreclr; then
  fw="$(framework_dir "$rootfs")"
  for f in createdump libcoreclrtraceptprovider.so libmscordaccore.so libmscordbi.so; do
    test -e "$fw/$f"
  done
fi
