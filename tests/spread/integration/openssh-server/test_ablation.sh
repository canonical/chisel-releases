#!/bin/bash
set -euo pipefail

removed_path=
backup_path=
daemon_pid=
restore_binary() {
  if [ -n "$removed_path" ] && [ -e "$backup_path" ]; then
    mv "$backup_path" "$removed_path"
  fi
  removed_path=
  backup_path=
}
cleanup() {
  restore_binary
  if [ -n "$daemon_pid" ]; then
    kill "$daemon_pid" 2>/dev/null || true
    wait "$daemon_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
ablate_binary() {
  removed_path="$1"
  backup_path="$2"
  mv "$removed_path" "$backup_path"
}

# A successful login exercises sshd, sshd-session, and sshd-auth together.
login_rootfs="$(install-slices openssh-server_bins openssh-server_config)"
mkdir -p "$login_rootfs/dev" "$login_rootfs/run/sshd" "$login_rootfs/root/.ssh" "$login_rootfs/tmp"
chmod 700 "$login_rootfs/root/.ssh"
chmod 1777 "$login_rootfs/tmp"
touch "$login_rootfs/dev/null"

# Chisel does not run the package's sysusers postinst step. Supply its sshd
# account, plus a shell and shadow entry for the test's root login.
printf 'sshd:x:100:65534:sshd privilege separation:/run/sshd:/usr/sbin/nologin\n' >> "$login_rootfs/etc/passwd"
printf 'root:*:0:0:99999:7:::\n' > "$login_rootfs/etc/shadow"
chmod 600 "$login_rootfs/etc/shadow"
sed -i '/^root:/s#[^:]*$#/usr/bin/dash#' "$login_rootfs/etc/passwd"

chroot "$login_rootfs" /usr/bin/ssh-keygen -q -t ed25519 -N '' -f /tmp/hostkey
chroot "$login_rootfs" /usr/bin/ssh-keygen -q -t ed25519 -N '' -f /tmp/clientkey
cp "$login_rootfs/tmp/clientkey.pub" "$login_rootfs/root/.ssh/authorized_keys"
chmod 600 "$login_rootfs/root/.ssh/authorized_keys"
cat > "$login_rootfs/tmp/sshd_config" <<'EOF'
Port 22222
ListenAddress 127.0.0.1
HostKey /tmp/hostkey
PidFile /tmp/sshd.pid
AuthorizedKeysFile /root/.ssh/authorized_keys
PermitRootLogin yes
StrictModes no
UsePAM no
PasswordAuthentication no
PubkeyAuthentication yes
PerSourcePenalties no
EOF
chroot "$login_rootfs" /usr/sbin/sshd -t -f /tmp/sshd_config
start_daemon() {
  chroot "$login_rootfs" /usr/sbin/sshd -D -e -f /tmp/sshd_config > "$login_rootfs/tmp/sshd.log" 2>&1 &
  daemon_pid=$!
}
ssh_login() {
  timeout 10 chroot "$login_rootfs" /usr/bin/ssh -n -q \
    -i /tmp/clientkey -p 22222 -o BatchMode=yes -o ConnectTimeout=3 \
    -o ConnectionAttempts=3 -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null root@127.0.0.1 'exit 0'
}
start_daemon
ssh_login
for helper in sshd-session sshd-auth; do
  ablate_binary "$login_rootfs/usr/lib/openssh/$helper" "$login_rootfs/tmp/$helper.ablation"
  if ssh_login; then
    echo "SSH login unexpectedly worked without $helper" >&2
    exit 1
  fi
  restore_binary
  ssh_login
done

# The listener itself is required to start a new server.
kill "$daemon_pid"
wait "$daemon_pid" 2>/dev/null || true
daemon_pid=
ablate_binary "$login_rootfs/usr/sbin/sshd" "$login_rootfs/tmp/sshd.ablation"
if chroot "$login_rootfs" /usr/sbin/sshd -t -f /tmp/sshd_config 2>/dev/null; then
  echo 'sshd unexpectedly started without its listener binary' >&2
  exit 1
fi
restore_binary
start_daemon
ssh_login

# The Ubuntu generator is needed for ssh.socket to honor a custom SSH port.
generator_rootfs="$(install-slices openssh-server_bins openssh-server_config openssh-server_services)"
printf 'Port 22345\n' > "$generator_rootfs/etc/ssh/sshd_config"
mkdir -p "$generator_rootfs/tmp/generator/normal" "$generator_rootfs/tmp/generator/early" "$generator_rootfs/tmp/generator/late"
socket="$generator_rootfs/usr/lib/systemd/system/ssh.socket"
test -f "$generator_rootfs/usr/lib/systemd/system/ssh.service"
grep -Fxq 'ListenStream=0.0.0.0:22' "$socket"
grep -Fxq 'ListenStream=[::]:22' "$socket"
generator=/usr/lib/systemd/system-generators/sshd-socket-generator
addresses="$generator_rootfs/tmp/generator/normal/ssh.socket.d/addresses.conf"
run_generator() {
  chroot "$generator_rootfs" "$generator" \
    /tmp/generator/normal /tmp/generator/early /tmp/generator/late
}
run_generator
grep -Fxq 'ListenStream=' "$addresses"
grep -Fxq 'ListenStream=0.0.0.0:22345' "$addresses"
grep -Fxq 'ListenStream=[::]:22345' "$addresses"
ablate_binary "$generator_rootfs$generator" "$generator_rootfs/tmp/sshd-socket-generator.ablation"
rm -f "$addresses"
if run_generator 2>/dev/null; then
  echo 'socket generator unexpectedly ran without its binary' >&2
  exit 1
fi
# With no generated drop-in, ssh.socket keeps its packaged port 22.
test ! -e "$addresses"
grep -Fxq 'ListenStream=0.0.0.0:22' "$socket"
restore_binary
run_generator
grep -Fxq 'ListenStream=0.0.0.0:22345' "$addresses"
