rootfs="$(install-slices openssl_bins)"

chroot "$rootfs" openssl version | grep -Fq OpenSSL
chroot "$rootfs" c_rehash -h | grep -Fq Usage
