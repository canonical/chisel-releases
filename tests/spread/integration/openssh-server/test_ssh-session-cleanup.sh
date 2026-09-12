source "$(dirname "$0")/helpers.sh"

# pgrep needs /proc, the pty login needs /dev with its submounts: on lxd
# /dev/ptmx is a bind mount of /dev/pts/ptmx, and openpty() needs both
mounted=()
_mount() {
  mkdir -p "$1/dev" "$1/proc"
  mount --rbind /dev "$1/dev"
  mount --make-rslave "$1/dev"
  mount --bind /proc "$1/proc"
  mounted+=("$1")
}
_unmount() {
  local rootfs
  for rootfs in "${mounted[@]}"; do
    umount --lazy "$rootfs/proc" || true
    umount --lazy "$rootfs/dev" || true
  done
}

# test slice by itself. no session to clean up so no output
rootfs="$(install-slices openssh-server_ssh-session-cleanup)"
trap 'cleanup_sshd; _unmount' EXIT
_mount "$rootfs"
test -z "$(chroot "$rootfs" /usr/lib/openssh/ssh-session-cleanup 2>&1)"

# test cleaning up a real interactive session
slices=(
  openssh-server_ssh-session-cleanup
  openssh-server_bins
  openssh-client_bins
  bash_bins
  coreutils_sleep
)
rootfs="$(install-slices "${slices[@]}")"
_mount "$rootfs"
prepare_sshd "$rootfs" /usr/bin/bash
cat > "$rootfs/etc/ssh/sshd_config" <<'EOF'
HostKey /etc/ssh/ssh_host_ed25519_key
PubkeyAuthentication yes
PasswordAuthentication no
UsePAM no
PidFile none
EOF
start_sshd "$rootfs"

# NOTE: ssh-session-cleanup script finds the session by grepping for
# "sshd-session: <user>@pts/<n>". this is buggy under emulation so we have to
# work around this and force sessions' process' name to what ssh-session-cleanup
# expects.
session='sshd-session: tester@pts'
chroot "$rootfs" ssh "${ssh_opts[@]}" -tt tester@127.0.0.1 \
  'exec -a "sshd-session: $USER@${SSH_TTY#/dev/}" sleep 300' \
  < /dev/null > /dev/null 2>&1 &
ssh_pid=$!

# pgrep ourselves to see if it's up
for _ in $(seq 60); do
  chroot "$rootfs" pgrep --full "$session" > /dev/null && break
  kill -0 "$ssh_pid"
  sleep 0.5
done

# run the session cleanup which will internally do the same pgrep
chroot "$rootfs" /usr/lib/openssh/ssh-session-cleanup | grep -Fq "sending SIGTERM"

# the session is gone, so its client exits and nothing matches any more
for _ in $(seq 60); do
  kill -0 "$ssh_pid" 2> /dev/null || break
  sleep 0.5
done
# plain test commands, since set -e never fires on a failing "! cmd"
test ! -e "/proc/$ssh_pid"
test -z "$(chroot "$rootfs" pgrep --full "$session")"
