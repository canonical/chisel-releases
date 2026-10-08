#!/bin/bash
#spellchecker: ignore rootfs fsi

# What a consumer can do with dotnet-sdk-10.0_standard: everything core and
# publish can, with globalization left on. Native AOT comes in on amd64 and
# arm64; the dotnet-sdk-aot-10.0 tests compile with it.

# shellcheck source=tests/spread/integration/dotnet-sdk-10.0/helpers.sh
. ./helpers.sh

rootfs="$(sdk_rootfs dotnet-sdk-10.0_standard)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet new console --output /newapp --no-restore \
  | grep -Fq 'The template "Console App" was created successfully.'
chroot "$rootfs" /usr/bin/dotnet build /newapp/newapp.csproj --configuration Release -warnaserror
chroot "$rootfs" /newapp/bin/Release/net10.0/newapp | grep -Fxq "Hello, World!"
chroot "$rootfs" /usr/bin/dotnet fsi /helloworld.fsx | grep -Fxq "Hello from F#"

rid="$(sdk_rid "$rootfs")"
test -n "$rid"
chroot "$rootfs" /usr/bin/dotnet publish /hello/Hello.csproj --configuration Release \
  --runtime "$rid" --self-contained --output /sc
chroot "$rootfs" /sc/Hello | grep -Fxq "Hello, World!"

if is_coreclr; then
  test -d "$(echo "$rootfs"/usr/lib/dotnet/packs/runtime.*.Microsoft.DotNet.ILCompiler)"
fi
