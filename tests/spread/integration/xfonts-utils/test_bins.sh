rootfs="$(install-slices xfonts-utils_bins)"

mkdir -p $rootfs/tmp/fonts
mkdir -p $rootfs/dev
cp sample.bdf $rootfs/tmp/fonts/sample.bdf
cp 6x13.bdf $rootfs/tmp/fonts/6x13.bdf

# bdftopcf
chroot "$rootfs" bdftopcf --foo 2>&1 | grep -iq "usage: bdftopcf"

chroot "$rootfs" bdftopcf /tmp/fonts/sample.bdf -o /tmp/fonts/sample.pcf
test -f "$rootfs/tmp/fonts/sample.pcf"

# bdftruncate
chroot "$rootfs" bdftruncate --foo 2>&1 | grep -iq "usage: bdftruncate"
chroot "$rootfs" bdftruncate 0x3200 < $rootfs/tmp/fonts/sample.bdf >$rootfs/tmp/fonts/sample-truncated.bdf
test -f "$rootfs/tmp/fonts/sample-truncated.bdf"

# fonttosfnt
chroot "$rootfs" fonttosfnt --foo 2>&1 | tr '\n' ' ' | grep -iq "usage: fonttosfnt"
chroot "$rootfs" fonttosfnt -o /tmp/fonts/sample.ttf /tmp/fonts/sample.bdf
test -f "$rootfs/tmp/fonts/sample.ttf"

# ucs2any
chroot "$rootfs" ucs2any /tmp/fonts/6x13.bdf
