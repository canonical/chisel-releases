#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices libgdk-pixbuf-2.0-0_bins librsvg2-common_libs)"
bin_path=$(find "$rootfs" -type f -executable -name "gdk-pixbuf-query-loaders" -print | sed "s|$rootfs||")

# NOTE: this will actually load and execute functions from the loader, so
# it is also a test that the loader deps are correct
svg_loader=$(chroot "$rootfs" "$bin_path")

echo "$svg_loader" | grep -q "libpixbufloader_svg.so"

