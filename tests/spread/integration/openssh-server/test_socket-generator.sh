rootfs="$(install-slices openssh-server_socket-generator)"
mkdir -p "$rootfs/gen/normal" "$rootfs/gen/early" "$rootfs/gen/late"
override="$rootfs/gen/normal/ssh.socket.d/addresses.conf"
run_generator() {
  chroot "$rootfs" /usr/lib/systemd/system-generators/sshd-socket-generator \
    /gen/normal /gen/early /gen/late
}

# the stock config listens on the default port, so ssh.socket is left alone
run_generator
test ! -e "$override"

# a port set in a drop-in, via the stock config's Include, ends up in ssh.socket
echo "Port 22345" > "$rootfs/etc/ssh/sshd_config.d/port.conf"
run_generator
grep -Fxq "ListenStream=0.0.0.0:22345" "$override"
