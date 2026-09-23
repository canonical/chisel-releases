#!/bin/bash
# Shared setup for the independent end-to-end and ablation tests.

rootfs=$(install-slices openssh-server_bins openssh-server_config openssh-server_services)
mkdir -p "$rootfs/dev" "$rootfs/root" "$rootfs/run/sshd" "$rootfs/tmp"
touch "$rootfs/dev/null"
printf 'sshd:x:100:65534::/run/sshd:/usr/sbin/nologin\n' >> "$rootfs/etc/passwd"
printf 'root:*:0:0:99999:7:::\n' > "$rootfs/etc/shadow"
chmod 600 "$rootfs/etc/shadow"
sed -i '/^root:/s#[^:]*$#/usr/bin/dash#' "$rootfs/etc/passwd"
ssh-keygen -q -t ed25519 -N '' -f "$rootfs/tmp/key"
cat > "$rootfs/tmp/sshd.conf" <<'CONFIG'
Port 22222
ListenAddress 127.0.0.1
HostKey /tmp/key
AuthorizedKeysFile /tmp/key.pub
PermitRootLogin yes
StrictModes no
UsePAM no
PasswordAuthentication no
PerSourcePenalties no
CONFIG

ssh_command() {
  timeout 10 ssh -F /dev/null -n -q -i "$rootfs/tmp/key" -p 22222 \
    -o BatchMode=yes -o ConnectTimeout=3 -o ConnectionAttempts=3 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@127.0.0.1 "$@"
}

chroot "$rootfs" /usr/sbin/sshd -D -f /tmp/sshd.conf > "$rootfs/tmp/sshd.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
