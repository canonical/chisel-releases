rootfs="$(install-slices mosquitto_bins)"
mkdir -p "$rootfs/tmp"

cleanup() {
  if [ -n "${broker_pid:-}" ]; then
    kill "$broker_pid" || true
    wait "$broker_pid" || true
    cat "$rootfs/var/log/mosquitto/mosquitto.log" || true
  fi
}
trap cleanup EXIT

chroot "$rootfs" mosquitto_ctrl dynsec init /tmp/dynsec.json adminuser adminpass

# there is no mosquitto user to drop privileges to
printf 'user root\n' >> "$rootfs/etc/mosquitto/mosquitto.conf"

# the unversioned plugin path is a symlink into mosquitto/
plugin=("$rootfs"/usr/lib/*-linux-*/mosquitto_dynamic_security.so)
test -e "${plugin[0]}"
cat > "$rootfs/etc/mosquitto/conf.d/dynsec.conf" <<EOF
listener 1883 127.0.0.1
plugin ${plugin[0]#"$rootfs"}
plugin_opt_config_file /tmp/dynsec.json
EOF

chroot "$rootfs" mosquitto -c /etc/mosquitto/mosquitto.conf &
broker_pid=$!
for ((i = 0; i < 50; i++)); do
  : 2> /dev/null > /dev/tcp/127.0.0.1/1883 && break
  kill -0 "$broker_pid"
  sleep 0.2
done

timeout 10 chroot "$rootfs" mosquitto_ctrl -h 127.0.0.1 -u adminuser -P adminpass \
  dynsec listClients | grep -Fxq "adminuser"
