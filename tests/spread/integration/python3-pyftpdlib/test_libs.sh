source "$(dirname "$0")/helpers.sh"

# Still run the cleanup even on test failure.
trap cleanup EXIT

rootfs="$(install-slices python3-pyftpdlib_libs)"
prepare_srv "$rootfs"

# Basic install smoke test
chroot "$rootfs" python3 -m pyftpdlib --help

# Anonymous hosting
chroot "$rootfs" /usr/bin/python3 -m pyftpdlib \
  --debug \
  --interface=127.0.0.1 \
  --port=2121 \
  --directory=/srv &
pyftpdlib_pid=$!
wait_for_ftp

[[ "$(curl ftp://127.0.0.1:2121/subdir/test-file)" == "Test file" ]]

cleanup

# With login and file upload.
chroot "$rootfs" /usr/bin/python3 -m pyftpdlib \
  --debug \
  --interface=127.0.0.1 \
  --port=2121 \
  --directory=/srv \
  --write \
  --username=testy \
  --password=testy &
pyftpdlib_pid=$!
wait_for_ftp

[[ "$(curl ftp://testy:testy@127.0.0.1:2121/subdir/test-file)" == "Test file" ]]

echo "Test upload" > test-upload
curl -T test-upload ftp://testy:testy@127.0.0.1:2121/test-upload
[[ "$(cat "$rootfs/srv/test-upload")" == "$(cat test-upload)" ]]
