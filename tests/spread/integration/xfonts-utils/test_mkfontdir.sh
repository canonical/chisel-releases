rootfs="$(install-slices xfonts-utils_mkfontdir)"

mkdir -p $rootfs/tmp/fonts
chroot "$rootfs" mkfontdir /tmp/fonts/
test -f $rootfs/tmp/fonts/fonts.dir
