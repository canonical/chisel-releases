rootfs="$(install-slices openssl_openssl)"

chroot "$rootfs" openssl sha1 <<< "test" | grep -Fq 4e1243bd22c66e76c2ba9eddc1f91394e57f9f83
