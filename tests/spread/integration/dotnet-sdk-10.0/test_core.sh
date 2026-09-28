#!/bin/bash
#spellchecker: ignore rootfs fsi

# What a consumer can do with dotnet-sdk-10.0_core: start from a template,
# script in F#, and publish a single-file app on the shared runtime, in
# invariant globalization mode. Anything self-contained comes with publish.

# shellcheck source=tests/spread/integration/dotnet-sdk-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(sdk_rootfs dotnet-sdk-10.0_core)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet new console --output /newapp --no-restore \
  | grep -Fq 'The template "Console App" was created successfully.'
chroot "$rootfs" /usr/bin/dotnet build /newapp/newapp.csproj --configuration Release -warnaserror
chroot "$rootfs" /newapp/bin/Release/net10.0/newapp | grep -Fxq "Hello, World!"

chroot "$rootfs" /usr/bin/dotnet fsi /helloworld.fsx | grep -Fxq "Hello from F#"

rid="$(sdk_rid "$rootfs")"
test -n "$rid"
if is_coreclr; then
  chroot "$rootfs" /usr/bin/dotnet publish /hello/Hello.csproj --configuration Release \
    --runtime "$rid" --no-self-contained -p:PublishSingleFile=true --output /single
  chroot "$rootfs" /single/Hello | grep -Fxq "Hello, World!"
fi

chroot "$rootfs" /usr/bin/dotnet publish /hello/Hello.csproj --configuration Release \
  --runtime "$rid" --self-contained --output /sc 2>&1 \
  | grep -Fq "error NU1101: Unable to find package Microsoft.NETCore.App.Runtime.$rid."
