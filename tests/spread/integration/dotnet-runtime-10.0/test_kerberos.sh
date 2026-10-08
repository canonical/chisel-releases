#!/bin/bash
#spellchecker: ignore rootfs gssapi

# What a consumer gets from dotnet-runtime-10.0_kerberos on top of core:
# Negotiate authentication, which hands the exchange to GSSAPI. Without a
# ticket GSSAPI refuses the exchange, but only a loaded GSSAPI answers at
# all; core fails before asking.

# shellcheck source=tests/spread/integration/dotnet-runtime-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(probe_rootfs dotnet-runtime-10.0_kerberos)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll | grep -Fxq "Hello, World!"
chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll negotiate | grep -q "^negotiate: ok "
