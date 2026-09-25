#!/bin/bash
#spellchecker: ignore rootfs inetd

# What a consumer gets from systemd_socket-activate: a socket bound on a
# program's behalf, handed over once someone connects, or one connection at a
# time on its stdin and stdout. dash is the program here.

rootfs="$(install-slices systemd_socket-activate dash_bins)"
chroot "$rootfs" /usr/bin/systemd-socket-activate --version | grep -Eq '^systemd [0-9]+ '

wait_port() {
  for _ in $(seq 1 60); do
    : 2> /dev/null > "/dev/tcp/127.0.0.1/$1" && return
    kill -0 "$activator"
    sleep 0.5
  done
  return 1
}
trap 'kill "${activator:-}" 2>/dev/null || true' EXIT

# the first connection starts the program with the listening socket as fd 3
chroot "$rootfs" systemd-socket-activate -l 127.0.0.1:2345 \
  sh -c 'echo "$LISTEN_FDS $LISTEN_PID $$" > /activated' &
activator=$!
wait_port 2345
wait "$activator"
read -r fds pid self < "$rootfs/activated"
test "$fds" = 1
test "$pid" = "$self"

# with --inetd and --accept, each connection gets a program of its own
chroot "$rootfs" systemd-socket-activate --inetd --accept -l 127.0.0.1:2346 \
  sh -c 'read -r line; echo "got $line"' &
activator=$!
wait_port 2346
for word in hello again; do
  exec 3<> /dev/tcp/127.0.0.1/2346
  echo "$word" >&3
  read -r reply <&3
  exec 3>&-
  test "$reply" = "got $word"
done
