#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices libgdk-pixbuf-2.0-0_bins)"
bin_path=$(find "$rootfs" -type f -executable -name "gdk-pixbuf-query-loaders" -print | sed "s|$rootfs||")

empty_loaders=$(chroot "$rootfs" "$bin_path")

echo "$empty_loaders" | grep -q "GdkPixbuf Image Loader Modules file"
echo "$empty_loaders" | grep -q "Automatically generated file, do not edit"
echo "$empty_loaders" | grep -q "LoaderDir = $(dirname "$bin_path")/2.[0-9]\{1,\}.0/loaders"
