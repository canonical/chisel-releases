#!/bin/bash
#spellchecker: ignore rootfs tracept

# What a consumer can do with dotnet-runtime-10.0_minimal: run a console app
# in invariant globalization mode, and nothing that needs crypto,
# compression, ICU or time zones.

# shellcheck source=tests/spread/integration/dotnet-runtime-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(probe_rootfs dotnet-runtime-10.0_minimal)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll | grep -Fxq "Hello, World!"
# an app started through its own executable finds the runtime too
chroot "$rootfs" /app/Hello | grep -Fxq "Hello, World!"

# what the shipped assemblies reference is shipped with them
for probe in collections concurrent uri memory; do
  chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll "$probe" | grep -q "^$probe: ok "
done

# the gates stay shut: crypto and compression open in core, ICU and the
# zone files in standard
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll crypto \
  | grep -Fq "crypto: FAIL FileNotFoundException: Could not load file or assembly 'System.Security.Cryptography,"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll compression \
  | grep -Fq "compression: FAIL FileNotFoundException: Could not load file or assembly 'System.IO.Compression,"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll culture | grep -Fq "culture: FAIL CultureNotFoundException"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll timezone | grep -Fq "timezone: FAIL TimeZoneNotFoundException"

# the tracing provider is dotnet-runtime-10.0_tracing's
test ! -e "$(framework_dir "$rootfs")/libcoreclrtraceptprovider.so"
