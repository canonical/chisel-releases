#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer can do with aspnetcore-runtime-10.0_standard: serve the app
# with globalization left on.

# shellcheck source=tests/spread/integration/aspnetcore-runtime-10.0/helpers.sh
. ./helpers.sh

rootfs="$(web_rootfs aspnetcore-runtime-10.0_standard)"

serve "$rootfs" /usr/bin/dotnet /web/Hello.dll
curl -fsS http://127.0.0.1:5108/ | grep -Fxq "Hello World!"
