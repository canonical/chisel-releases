source "$(dirname "$0")/helpers.sh"

setup sctp
# Without SCTP in the kernel the socket call fails, which is past loading libsctp.
out="$(chroot . $java -cp / SctpOpen 2>&1)" || true
echo "$out" | grep -E "sctp channel open|SocketException: Protocol not"
