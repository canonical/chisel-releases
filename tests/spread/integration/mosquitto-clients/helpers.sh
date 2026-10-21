#!/usr/bin/env bash

# runs the broker in the background on its default local-only listener, which
# takes anonymous clients, and waits for it to listen
start_broker() {
  local i
  broker_rootfs="$1"
  # there is no mosquitto user to drop privileges to
  printf 'user root\n' >> "$broker_rootfs/etc/mosquitto/mosquitto.conf"
  chroot "$broker_rootfs" mosquitto -c /etc/mosquitto/mosquitto.conf &
  broker_pid=$!
  for ((i = 0; i < 50; i++)); do
    : 2> /dev/null > /dev/tcp/127.0.0.1/1883 && break
    kill -0 "$broker_pid"
    sleep 0.2
  done
}

stop_broker() {
  if [ -n "${broker_pid:-}" ]; then
    kill "$broker_pid" || true
    wait "$broker_pid" || true
    cat "$broker_rootfs/var/log/mosquitto/mosquitto.log" || true
  fi
}
