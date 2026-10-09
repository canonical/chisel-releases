source "$(dirname "$0")/helpers.sh"

# Still run the cleanup even on test failure.
trap cleanup EXIT

rootfs="$(install-slices python3-pyftpdlib_ftps)"
prepare_srv "$rootfs"
mkdir "$rootfs/tls"

cp make_cert.py "$rootfs"
chroot "$rootfs" python3 make_cert.py

chroot "$rootfs" /usr/bin/python3 -m pyftpdlib \
  --debug \
  --interface=127.0.0.1 \
  --port=2121 \
  --directory=/srv \
  --tls \
  --keyfile=/tls/key.pem \
  --certfile=/tls/cert.pem \
  --tls-control-required \
  --tls-data-required &
pyftpdlib_pid=$!
wait_for_ftp

[[ "$(curl --ssl-reqd --insecure ftp://127.0.0.1:2121/subdir/test-file)" == "Test file" ]]

# The server refuses a client that does not upgrade to TLS.
# A bare `!` is exempt from errexit, hence the explicit exit.
! curl ftp://127.0.0.1:2121/subdir/test-file || exit 1
