#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer gets from dotnet-sdk-10.0_publish on top of core: apps that
# carry their own runtime, as a folder or, where coreclr runs, as one file.

# shellcheck source=tests/spread/integration/dotnet-sdk-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(sdk_rootfs dotnet-sdk-10.0_publish)"
trap 'umount "$rootfs/proc"' EXIT

rid="$(sdk_rid "$rootfs")"
test -n "$rid"
chroot "$rootfs" /usr/bin/dotnet publish /hello/Hello.csproj --configuration Release \
  --runtime "$rid" --self-contained --output /sc
test -e "$rootfs/sc/System.Private.CoreLib.dll"
chroot "$rootfs" /sc/Hello | grep -Fxq "Hello, World!"

if is_coreclr; then
  chroot "$rootfs" /usr/bin/dotnet publish /hello/Hello.csproj --configuration Release \
    --runtime "$rid" --self-contained -p:PublishSingleFile=true --output /single
  test "$(find "$rootfs/single" -type f ! -name '*.pdb' -printf '%f\n')" = "Hello"
  chroot "$rootfs" /single/Hello | grep -Fxq "Hello, World!"
fi
