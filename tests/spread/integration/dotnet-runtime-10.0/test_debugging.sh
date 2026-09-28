#!/bin/bash
#spellchecker: ignore rootfs createdump mscordaccore mscordbi

# What a consumer gets from dotnet-runtime-10.0_debugging on top of core:
# crash dumps of an app, taken from outside it or written when it fails fast.
# libmscordbi is only there for an attached debugger; createdump reads the
# app through libmscordaccore.

# shellcheck source=tests/spread/integration/dotnet-runtime-10.0/helpers.sh
. ./helpers.sh

export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
rootfs="$(probe_rootfs dotnet-runtime-10.0_debugging)"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll | grep -Fxq "Hello, World!"

fw="$(framework_dir "$rootfs")"
if ! is_coreclr; then
  # the slice is core alone here
  for f in createdump libmscordaccore.so libmscordbi.so; do
    test ! -e "$fw/$f"
  done
  exit 0
fi

chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll wait > "$rootfs/tmp/wait.out" &
pid=$!
for _ in $(seq 30); do
  grep -q "^pid " "$rootfs/tmp/wait.out" && break
  sleep 1
done
chroot "$rootfs" "${fw#"$rootfs"}/createdump" --full --name /tmp/live.dmp "$pid"
kill "$pid"
wait "$pid" || true
test -s "$rootfs/tmp/live.dmp"

# the runtime runs createdump itself when an app fails fast
if DOTNET_DbgEnableMiniDump=1 DOTNET_DbgMiniDumpName=/tmp/crash.dmp \
  chroot "$rootfs" /usr/bin/dotnet /app/Hello.dll crash; then
  echo "the crash probe exited cleanly" >&2
  exit 1
fi
test -s "$rootfs/tmp/crash.dmp"
