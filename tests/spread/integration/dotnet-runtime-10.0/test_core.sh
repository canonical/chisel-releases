#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer can do with dotnet-runtime-10.0_core: run an app that
# hashes and compresses, still in invariant globalization mode.

# shellcheck source=tests/spread/integration/dotnet-runtime-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(probe_rootfs dotnet-runtime-10.0_core)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll | grep -Fxq "Hello, World!"
chroot "$rootfs" /app/Hello | grep -Fxq "Hello, World!"
for probe in collections concurrent uri memory; do
  chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll "$probe" | grep -q "^$probe: ok "
done

# SHA-256 of "abc", through the OpenSSL shim
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll crypto \
  | grep -Fxq "crypto: ok BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"
# a gzip round trip, through the compression shim
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll compression | grep -Fxq "compression: ok chisel chisel chisel"

# ICU and the zone files open in standard, GSSAPI in kerberos
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll culture | grep -Fq "culture: FAIL CultureNotFoundException"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll timezone | grep -Fq "timezone: FAIL TimeZoneNotFoundException"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll negotiate | grep -Fq "negotiate: FAIL TypeInitializationException"
