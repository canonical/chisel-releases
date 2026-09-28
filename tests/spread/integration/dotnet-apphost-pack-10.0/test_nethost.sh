#!/bin/bash
#spellchecker: ignore rootfs nethost hostfxr

# What a consumer gets from dotnet-apphost-pack-10.0_nethost: the library and
# headers a native program uses to find hostfxr and host .NET itself.

# shellcheck source=tests/spread/integration/dotnet-apphost-pack-10.0/helpers.sh
. ./helpers.sh

# Build the probe with the release's own gcc against the slice's headers and
# library, in a rootfs of its own, so nothing is installed on the test host.
tools="$(install-slices gcc_gcc libc6-dev_libs dotnet-apphost-pack-10.0_nethost)"
native="$(native_dir "$tools")"
cp nethost_probe.c "$tools/"
chroot "$tools" gcc -I"$native" /nethost_probe.c -L"$native" -lnethost -Wl,-rpath,"$native" -o /nethost-probe

# the slice on its own: the headers are there and the library loads, but
# there is no hostfxr to find
rootfs="$(install-slices dotnet-apphost-pack-10.0_nethost)"
for header in coreclr_delegates.h hostfxr.h nethost.h; do
  test -e "$rootfs$native/$header"
done
test -e "$rootfs$native/libnethost.a"
cp "$tools/nethost-probe" "$rootfs/"
chroot "$rootfs" /nethost-probe | grep -Fxq "get_hostfxr_path failed: 0x80008083"
clean-rootfs "$rootfs"

# with hostfxr installed, nethost finds it where the host says .NET lives
rootfs="$(install-slices dotnet-apphost-pack-10.0_nethost dotnet-hostfxr-10.0_libs)"
cp "$tools/nethost-probe" "$rootfs/"
chroot "$rootfs" /nethost-probe | grep -Eq '^hostfxr: /usr/lib/dotnet/host/fxr/10\.0\.[0-9]+/libhostfxr\.so$'
