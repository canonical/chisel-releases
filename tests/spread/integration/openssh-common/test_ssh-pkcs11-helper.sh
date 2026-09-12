rootfs="$(install-slices openssh-common_ssh-pkcs11-helper)"
mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"

# the helper serves ssh over its stdin; with nothing to read it logs the eof
# and exits
chroot "$rootfs" /usr/lib/openssh/ssh-pkcs11-helper -v < /dev/null 2>&1 | grep -Fq "read eof"
