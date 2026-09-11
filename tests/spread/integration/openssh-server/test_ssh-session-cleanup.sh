set -eu
source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices openssh-server_ssh-session-cleanup)"
trap cleanup EXIT
mount_rootfs "$rootfs"

# no interactive sshd sessions around, so nothing to kill and nothing to say
test -z "$(chroot "$rootfs" /usr/lib/openssh/ssh-session-cleanup 2>&1)"

# now with a live interactive session, which is what the script is there to end
rootfs="$(install-slices openssh-server_ssh-session-cleanup openssh-server_bins dash_bins coreutils_sleep)"
mount_rootfs "$rootfs"
prepare_sshd "$rootfs"
start_sshd "$rootfs"

session='sshd-session: tester@pts'
chroot "$rootfs" ssh "${ssh_opts[@]}" -tt tester@127.0.0.1 'sleep 300' < /dev/null > /dev/null 2>&1 &
ssh_pid=$!
for _ in $(seq 60); do
  chroot "$rootfs" pgrep -f "$session" > /dev/null && break
  kill -0 "$ssh_pid"
  sleep 0.5
done

chroot "$rootfs" /usr/lib/openssh/ssh-session-cleanup | grep -F "sending SIGTERM"
for _ in $(seq 60); do
  kill -0 "$ssh_pid" 2> /dev/null || break
  sleep 0.5
done
! kill -0 "$ssh_pid" 2> /dev/null
! chroot "$rootfs" pgrep -f "$session"
