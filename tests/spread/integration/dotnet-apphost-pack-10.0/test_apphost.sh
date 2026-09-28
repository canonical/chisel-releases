#!/bin/bash
#spellchecker: ignore rootfs apphost nethost singlefilehost

# What a consumer gets from dotnet-apphost-pack-10.0_apphost: the host the
# SDK copies into every framework-dependent app as its own executable. Until
# the SDK binds it to an app, it runs only to say so. The dotnet-sdk-10.0
# tests run a bound one.

# shellcheck source=tests/spread/integration/dotnet-apphost-pack-10.0/helpers.sh
. ./helpers.sh

rootfs="$(install-slices dotnet-apphost-pack-10.0_apphost)"
native="$(native_dir "$rootfs")"

chroot "$rootfs" "$native/apphost" 2>&1 | grep -Fq "This executable is not bound to a managed DLL to execute."

# the other hosts are slices of their own
test ! -e "$rootfs$native/singlefilehost"
test ! -e "$rootfs$native/libnethost.so"
