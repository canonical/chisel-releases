#!/bin/bash
set -euo pipefail
source ./setup_server.sh

# Each cut is disposable; restore a binary only when its failure was expected.
ablate() {
  local binary="$rootfs$1"
  shift
  mv "$binary" "$binary.disabled"
  if "$@" >/dev/null 2>&1; then
    echo "Unexpected success without $binary" >&2
    return 1
  fi
  mv "$binary.disabled" "$binary"
}

ssh_login() {
  local reply
  reply=$(ssh_command 'printf chisel-ok') || return
  [[ $reply == chisel-ok ]]
}

ssh_login
for helper in sshd-session sshd-auth; do
  ablate "/usr/lib/openssh/$helper" ssh_login
  ssh_login
done
ablate /usr/sbin/sshd chroot "$rootfs" /usr/sbin/sshd -t -f /tmp/sshd.conf
chroot "$rootfs" /usr/sbin/sshd -t -f /tmp/sshd.conf

# The socket generator must translate a custom port into a systemd override.
printf 'Port 22345\n' > "$rootfs/etc/ssh/sshd_config"
mkdir -p "$rootfs/tmp/gen/normal" "$rootfs/tmp/gen/early" "$rootfs/tmp/gen/late"
override="$rootfs/tmp/gen/normal/ssh.socket.d/addresses.conf"
run_generator() {
  chroot "$rootfs" /usr/lib/systemd/system-generators/sshd-socket-generator \
    /tmp/gen/normal /tmp/gen/early /tmp/gen/late
}

run_generator
grep -Fxq 'ListenStream=0.0.0.0:22345' "$override"
rm "$override"
ablate /usr/lib/systemd/system-generators/sshd-socket-generator run_generator
[[ ! -e $override ]]
grep -Fxq 'ListenStream=0.0.0.0:22' "$rootfs/usr/lib/systemd/system/ssh.socket"
run_generator
grep -Fxq 'ListenStream=0.0.0.0:22345' "$override"
