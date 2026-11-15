rootfs="$(install-slices openssl_bins)"

chroot "$rootfs" openssl version | grep -Fq OpenSSL
