#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer can do with dotnet-runtime-10.0_standard: format for a
# culture and resolve a time zone, with globalization left on.

# shellcheck source=tests/spread/integration/dotnet-runtime-10.0/helpers.sh
. ./helpers.sh

rootfs="$(probe_rootfs dotnet-runtime-10.0_standard)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll | grep -Fxq "Hello, World!"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll culture | grep -Fxq "culture: ok 1.234,5"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll timezone | grep -Fxq "timezone: ok Europe/Berlin"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll crypto | grep -q "^crypto: ok "
