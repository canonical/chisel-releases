rootfs="$(install-slices bash_bashbug)"

chroot "$rootfs" bashbug --help
