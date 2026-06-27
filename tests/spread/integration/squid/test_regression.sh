#!/usr/bin/env bash
# spellchecker: ignore rootfs
source "$(dirname "$0")/helpers.sh"

# regression test:
# squid_minimal's mutate checks for "default.conf" by name to pick
# between the minimal config and the deb default. If squid_core ever renames
# that file, or the file gets moved to a different slice,
# the check in mutate can silently misbehave. Both
# branches are exercised here to check.

# Branch 1: squid_core co-installed -> default.conf present -> deb config used.
rootfs="$(install-slices squid_core)"
! grep -qF "visible_hostname squid.minimal" "$rootfs/etc/squid/squid.conf"
cleanup

# Branch 2: squid_minimal alone -> no default.conf -> minimal config used.
rootfs="$(install-slices squid_minimal)"
grep -qF "visible_hostname squid.minimal" "$rootfs/etc/squid/squid.conf"
cleanup
