#!/bin/bash
#spellchecker: ignore rootfs nethost hostfxr

# What a consumer gets from dotnet-apphost-pack-10.0_nethost: the library and
# headers a native program uses to find hostfxr and host .NET itself.

# shellcheck source=tests/spread/integration/dotnet-apphost-pack-10.0/helpers.sh
. ./helpers.sh

probe() {
  local rootfs="$1" native
  native="$(native_dir "$rootfs")"
  # the library may need a newer libc than the host's, so only the probe's
  # own symbols are resolved here
  gcc -I"$rootfs$native" nethost_probe.c -L"$rootfs$native" -lnethost \
    -Wl,--allow-shlib-undefined -Wl,-rpath,"$native" -o "$rootfs/nethost-probe"
}

# the slice on its own: the headers are there and the library loads, but
# there is no hostfxr to find
rootfs="$(install-slices dotnet-apphost-pack-10.0_nethost)"
native="$(native_dir "$rootfs")"
for header in coreclr_delegates.h hostfxr.h nethost.h; do
  test -e "$rootfs$native/$header"
done
test -e "$rootfs$native/libnethost.a"
probe "$rootfs"
chroot "$rootfs" /nethost-probe | grep -Fxq "get_hostfxr_path failed: 0x80008083"
clean-rootfs "$rootfs"

# with hostfxr installed, nethost finds it where the host says .NET lives
rootfs="$(install-slices dotnet-apphost-pack-10.0_nethost dotnet-hostfxr-10.0_libs)"
probe "$rootfs"
chroot "$rootfs" /nethost-probe | grep -Eq '^hostfxr: /usr/lib/dotnet/host/fxr/10\.0\.[0-9]+/libhostfxr\.so$'
