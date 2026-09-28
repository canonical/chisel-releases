#!/bin/bash
#spellchecker: ignore rootfs apphost singlefilehost

# What a consumer gets from dotnet-apphost-pack-10.0_singlefilehost: the host
# that a self-contained single-file app carries, with the runtime linked in.
# Until the SDK binds it to an app, it runs only to say so. The
# dotnet-sdk-10.0 tests publish a bound one.

# shellcheck source=tests/spread/integration/dotnet-apphost-pack-10.0/helpers.sh
. ./helpers.sh

rootfs="$(install-slices dotnet-apphost-pack-10.0_singlefilehost)"
native="$(native_dir "$rootfs")"

if ! is_coreclr; then
  test ! -e "$rootfs$native/singlefilehost"
  exit 0
fi

chroot "$rootfs" "$native/singlefilehost" 2>&1 | grep -Fq "This executable is not bound to a managed DLL to execute."
test ! -e "$rootfs$native/apphost"
