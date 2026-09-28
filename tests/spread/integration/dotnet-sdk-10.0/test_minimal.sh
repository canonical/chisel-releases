#!/bin/bash
#spellchecker: ignore rootfs doclib inheritdoc

# What a consumer can do with dotnet-sdk-10.0_minimal: build and publish an
# app that runs on the shared runtime, warnings as errors, in invariant
# globalization mode. Templates come with core, and anything self-contained
# with publish.

# shellcheck source=tests/spread/integration/dotnet-sdk-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(sdk_rootfs dotnet-sdk-10.0_minimal)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet --info | grep -Fq ".NET SDK:"

chroot "$rootfs" /usr/bin/dotnet build /hello/Hello.csproj --configuration Release -warnaserror
chroot "$rootfs" /usr/bin/dotnet /hello/bin/Release/net10.0/Hello.dll | grep -Fxq "Hello, World!"
# the app's own executable is the apphost
chroot "$rootfs" /hello/bin/Release/net10.0/Hello | grep -Fxq "Hello, World!"
chroot "$rootfs" /usr/bin/dotnet publish /hello/Hello.csproj --configuration Release --no-build --output /pub
chroot "$rootfs" /pub/Hello | grep -Fxq "Hello, World!"

# documentation builds without the targeting packs' IntelliSense docs
test -z "$(find "$rootfs/usr/lib/dotnet/packs" -path '*/ref/*' -name '*.xml' -print -quit)"
chroot "$rootfs" /usr/bin/dotnet build /doclib/Lib.csproj --configuration Release -warnaserror
grep -Fq "inheritdoc" "$rootfs/doclib/bin/Release/net10.0/Lib.xml"

chroot "$rootfs" /usr/bin/dotnet new console --output /newapp 2>&1 \
  | grep -Fq "No templates or subcommands found matching: 'console'."
rid="$(sdk_rid "$rootfs")"
test -n "$rid"
chroot "$rootfs" /usr/bin/dotnet publish /hello/Hello.csproj --configuration Release \
  --runtime "$rid" --self-contained --output /sc 2>&1 \
  | grep -Fq "error NU1101: Unable to find package Microsoft.NETCore.App.Runtime.$rid."
