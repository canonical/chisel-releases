rootfs="$(install-slices xfonts-utils_mkfontscale)"

# pass an invaliud arg to get usage
chroot "$rootfs" mkfontscale -foo 2>&1 | tr '\n' ' ' | grep -iq "usage: mkfontscale"

# index the fonts in /tmp/fonts
mkdir -p $rootfs/tmp/fonts
chroot "$rootfs" mkfontscale -b -s -l /tmp/fonts/
test -f $rootfs/tmp/fonts/fonts.dir
