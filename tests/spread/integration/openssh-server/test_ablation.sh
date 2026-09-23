#!/bin/bash
set -euo pipefail

rootfs=$(install-slices openssh-server_bins openssh-server_config openssh-server_services)
server_pid=
hidden=
restore() {
  if [ -n "$hidden" ] && [ -e "$hidden.disabled" ]; then
    mv "$hidden.disabled" "$hidden"
  fi
  hidden=
}
cleanup() {
  restore
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
hide() { hidden="$1"; mv "$hidden" "$hidden.disabled"; }
expect_failure() {
  if "$@"; then
    echo "Unexpected success: $*" >&2
    exit 1
  fi
}

# Serve a real key-authenticated login from the sliced rootfs.
mkdir -p "$rootfs/dev" "$rootfs/run/sshd" "$rootfs/root" "$rootfs/tmp"
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
chroot "$rootfs" /usr/sbin/sshd -t -f /tmp/sshd.conf
chroot "$rootfs" /usr/sbin/sshd -D -f /tmp/sshd.conf > "$rootfs/tmp/sshd.log" 2>&1 &
server_pid=$!
login() {
  local reply
  reply=$(timeout 10 ssh -F /dev/null -n -q -i "$rootfs/tmp/key" -p 22222 \
    -o BatchMode=yes -o ConnectTimeout=3 -o ConnectionAttempts=3 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    root@127.0.0.1 'printf chisel-ok') || return
  test "$reply" = chisel-ok
}
login
for helper in sshd-session sshd-auth; do
  hide "$rootfs/usr/lib/openssh/$helper"
  expect_failure login
  restore
  login
done
hide "$rootfs/usr/sbin/sshd"
expect_failure chroot "$rootfs" /usr/sbin/sshd -t -f /tmp/sshd.conf
restore
chroot "$rootfs" /usr/sbin/sshd -t -f /tmp/sshd.conf

# Without the generator, ssh.socket keeps its packaged port 22.
printf 'Port 22345\n' > "$rootfs/etc/ssh/sshd_config"
mkdir -p "$rootfs/tmp/gen/normal" "$rootfs/tmp/gen/early" "$rootfs/tmp/gen/late"
override="$rootfs/tmp/gen/normal/ssh.socket.d/addresses.conf"
generate() {
  chroot "$rootfs" /usr/lib/systemd/system-generators/sshd-socket-generator \
    /tmp/gen/normal /tmp/gen/early /tmp/gen/late
}
generate
grep -Fxq 'ListenStream=0.0.0.0:22345' "$override"
grep -Fxq 'ListenStream=[::]:22345' "$override"
hide "$rootfs/usr/lib/systemd/system-generators/sshd-socket-generator"
rm "$override"
expect_failure generate
test ! -e "$override"
grep -Fxq 'ListenStream=0.0.0.0:22' "$rootfs/usr/lib/systemd/system/ssh.socket"
restore
generate
grep -Fxq 'ListenStream=0.0.0.0:22345' "$override"
