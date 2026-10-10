rootfs="$(install-slices openssl_c-rehash)"

chroot "$rootfs" openssl req -x509 -newkey rsa:2048 -nodes -subj /CN=localhost \
  -keyout /key.pem -out /etc/ssl/certs/localhost.pem

chroot "$rootfs" c_rehash /etc/ssl/certs

# c_rehash links <subject hash>.0 to the certificate.
hash="$(chroot "$rootfs" openssl x509 -hash -noout -in /etc/ssl/certs/localhost.pem)"
test "$(readlink "$rootfs/etc/ssl/certs/$hash.0")" = localhost.pem
