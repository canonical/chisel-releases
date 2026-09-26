source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices mosquitto_bins mosquitto-clients_bins)"
trap stop_broker EXIT
start_broker "$rootfs"

# retained, so the subscriber gets it however late it subscribes
chroot "$rootfs" mosquitto_pub -h 127.0.0.1 -t test/topic -r -m "hello, i am a test"
timeout 10 chroot "$rootfs" mosquitto_sub -h 127.0.0.1 -t test/topic -C 1 \
  | grep -Fxq "hello, i am a test"
