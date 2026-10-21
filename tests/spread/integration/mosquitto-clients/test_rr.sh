source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices mosquitto_bins mosquitto-clients_bins)"
trap stop_broker EXIT
start_broker "$rootfs"

# a persistent qos 1 session has the broker queue requests for the responder,
# so mosquitto_rr may send one before the responder reconnects
chroot "$rootfs" mosquitto_sub -h 127.0.0.1 -c -i responder -q 1 -t request/topic -E
{
  timeout 10 chroot "$rootfs" mosquitto_sub -h 127.0.0.1 -c -i responder -q 1 \
    -t request/topic -C 1 > /dev/null
  chroot "$rootfs" mosquitto_pub -h 127.0.0.1 -t response/topic -m pong
} &
responder_pid=$!

response="$(timeout 10 chroot "$rootfs" mosquitto_rr -h 127.0.0.1 -q 1 \
  -t request/topic -e response/topic -m ping)"
test "$response" = "pong"
wait "$responder_pid"
