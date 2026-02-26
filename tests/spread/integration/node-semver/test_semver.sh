#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices node-semver_scripts)"

chroot "$rootfs" semver --help | head -n1 | grep -q "SemVer"

# sort some versions
output=$(chroot "$rootfs" semver 1.0.0 2.0.0 1.5.0)
echo "$output" | grep -q "1.0.0"
echo "$output" | grep -q "1.5.0"
echo "$output" | grep -q "2.0.0"

# filter versions by range
output=$(chroot "$rootfs" semver --range ">=1.5.0 <2.0.0" 1.0.0 1.5.0 2.0.0)
echo "$output" | grep -q "1.5.0"
echo "$output" | grep -vq "1.0.0"
echo "$output" | grep -vq "2.0.0"

# increment a version
output=$(chroot "$rootfs" semver --increment minor 1.5.0)
echo "$output" | grep -q "1.6.0"

# coerce a string into SemVer
output=$(chroot "$rootfs" semver --coerce "v1.2.3")
echo "$output" | grep -q "1.2.3"
