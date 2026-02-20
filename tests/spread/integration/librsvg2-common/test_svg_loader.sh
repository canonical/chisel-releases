#!/usr/bin/env bash
# spellchecker: ignore rootfs libgdk pixbuf librsvg libpixbufloader

rootfs="$(install-slices libgdk-pixbuf-2.0-0_bins librsvg2-common_libs)"
bin_path=$(find "$rootfs" -type f -executable -name "gdk-pixbuf-query-loaders" -print | sed "s|$rootfs||")
svg_loader=$(chroot "$rootfs" "$bin_path")
echo "$svg_loader" | grep -q "libpixbufloader_svg.so"
