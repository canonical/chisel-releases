#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer can do with aspnetcore-runtime-10.0_minimal: serve a
# minimal-API app over HTTP, started through its own executable, in
# invariant globalization mode.

# shellcheck source=tests/spread/integration/aspnetcore-runtime-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(web_rootfs aspnetcore-runtime-10.0_minimal)"

serve "$rootfs" /web/Hello
curl -fsS http://127.0.0.1:5108/ | grep -Fxq "Hello World!"
