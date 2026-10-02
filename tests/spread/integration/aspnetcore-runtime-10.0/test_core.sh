#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer can do with aspnetcore-runtime-10.0_core: serve the same
# app with the whole ASP.NET Core framework underneath, still in invariant
# globalization mode.

# shellcheck source=tests/spread/integration/aspnetcore-runtime-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(web_rootfs aspnetcore-runtime-10.0_core)"

serve "$rootfs" /usr/bin/dotnet /web/Hello.dll
curl -fsS http://127.0.0.1:5108/ | grep -Fxq "Hello World!"
