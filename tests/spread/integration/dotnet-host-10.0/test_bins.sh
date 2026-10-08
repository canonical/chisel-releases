#!/bin/bash
#spellchecker: ignore rootfs hostfxr

# What a consumer gets from dotnet-host-10.0_bins: the dotnet muxer, which
# needs hostfxr for anything useful, and the files that tell an app started
# through its own executable where .NET lives.

rootfs="$(install-slices dotnet-host-10.0_bins)"

# the muxer runs, and says what it is missing
chroot "$rootfs" /usr/bin/dotnet --info 2>&1 | grep -Fq "[/usr/lib/dotnet/host/fxr] does not exist"

# one location file for any architecture, one for this one
test "$(cat "$rootfs/etc/dotnet/install_location")" = "/usr/lib/dotnet"
arch_files=("$rootfs"/etc/dotnet/install_location_*)
test "${#arch_files[@]}" -eq 1
test "$(cat "${arch_files[0]}")" = "/usr/lib/dotnet"
