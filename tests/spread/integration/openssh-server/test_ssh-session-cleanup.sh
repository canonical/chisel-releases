set -eu
source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices openssh-server_ssh-session-cleanup)"
trap cleanup EXIT
mount_rootfs "$rootfs"

# no interactive sshd sessions around, so nothing to kill and nothing to say
test -z "$(chroot "$rootfs" /usr/lib/openssh/ssh-session-cleanup 2>&1)"

# now with a live interactive session, which is what the script is there to end
rootfs="$(install-slices openssh-server_ssh-session-cleanup openssh-server_bins bash_bins coreutils_sleep)"
mount_rootfs "$rootfs"
prepare_sshd "$rootfs" /usr/bin/bash
write_sshd_config "$rootfs"
start_sshd "$rootfs"

# sshd-session retitles itself "sshd-session: <user>@pts/<n>" once the pty is
# up, and that title is what the script greps for. A title set at run time
# never shows in /proc under qemu-user, so the session's own command carries
# the same title from exec time on; natively the script matches both.
session='sshd-session: tester@pts'
chroot "$rootfs" ssh "${ssh_opts[@]}" -tt tester@127.0.0.1 \
  'exec -a "sshd-session: $USER@${SSH_TTY#/dev/}" sleep 300' < /dev/null > /dev/null 2>&1 &
ssh_pid=$!
for _ in $(seq 60); do
  chroot "$rootfs" pgrep --full "$session" > /dev/null && break
  kill -0 "$ssh_pid"
  sleep 0.5
done

chroot "$rootfs" /usr/lib/openssh/ssh-session-cleanup | grep -Fq "sending SIGTERM"
# the session is gone, so its client exits and nothing matches any more
for _ in $(seq 60); do
  kill -0 "$ssh_pid" 2> /dev/null || break
  sleep 0.5
done
! kill -0 "$ssh_pid" 2> /dev/null
! chroot "$rootfs" pgrep --full "$session"
