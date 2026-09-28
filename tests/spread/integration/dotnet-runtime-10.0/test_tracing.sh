#!/bin/bash
#spellchecker: ignore rootfs tracept lttng

# What a consumer gets from dotnet-runtime-10.0_tracing on top of core: the
# LTTng tracing provider, loaded into every app the runtime starts.

# shellcheck source=tests/spread/integration/dotnet-runtime-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(probe_rootfs dotnet-runtime-10.0_tracing)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll | grep -Fxq "Hello, World!"

if ! is_coreclr; then
  # the slice is core alone here
  test ! -e "$(framework_dir "$rootfs")/libcoreclrtraceptprovider.so"
  exit 0
fi

chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll wait > "$rootfs/tmp/wait.out" &
pid=$!
for _ in $(seq 30); do
  grep -q "^pid " "$rootfs/tmp/wait.out" && break
  sleep 1
done
grep -Fq "/libcoreclrtraceptprovider.so" "/proc/$pid/maps"
grep -Fq "/liblttng-ust.so.1" "/proc/$pid/maps"
kill "$pid"
wait "$pid" || true
