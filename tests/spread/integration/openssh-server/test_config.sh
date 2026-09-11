set -eu
rootfs="$(install-slices openssh-server_config openssh-server_bins base-passwd_data)"

mkdir -p "$rootfs/dev"
touch "$rootfs/dev/null"
# sshd -t still wants the privsep user, its chroot and a host key
useradd -R "$rootfs" -r -g nogroup -d /run/sshd -s /usr/sbin/nologin sshd
mkdir -p -m 0755 "$rootfs/run/sshd"
chroot "$rootfs" ssh-keygen -q -N "" -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

# the mutate script installs the default config where sshd looks for it
cmp "$rootfs/etc/ssh/sshd_config" "$rootfs/usr/share/openssh/sshd_config"
chroot "$rootfs" /usr/sbin/sshd -t
