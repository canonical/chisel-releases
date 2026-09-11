set -eu
rootfs="$(install-slices openssh-server_config openssh-server_bins base-passwd_data)"

mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
# sshd -t still wants the privsep user, its chroot and a host key
echo "sshd:x:101:65534::/run/sshd:/usr/sbin/nologin" >> "$rootfs/etc/passwd"
mkdir -p -m 0755 "$rootfs/run/sshd"
chroot "$rootfs" ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

# the shipped default sshd_config must parse
chroot "$rootfs" /usr/sbin/sshd -t -f /usr/share/openssh/sshd_config
