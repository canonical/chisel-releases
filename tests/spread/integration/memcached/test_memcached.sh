#!/bin/bash

rootfs="$(install-slices memcached_bins base-passwd_data)"

chroot "$rootfs" memcached -V

# the rootfs has no /dev/null for memcached -d to detach onto, so a daemon would
# hold the job's stdout open; run it in its own process group with its output closed off
setsid chroot "$rootfs" memcached -u root > /dev/null 2>&1 &
pid=$!
trap 'kill -- -"$pid" 2>/dev/null || true' EXIT

# Verify it listens on the default port (11211)
for _ in $(seq 10); do
    if (exec 3<> /dev/tcp/127.0.0.1/11211) 2> /dev/null; then
        break
    fi
    sleep 1
done

# Protocol: set <key> <flags> <exptime> <bytes>\r\n<value>\r\n, get <key>\r\n.
# quit makes memcached close the connection, which ends the read.
exec 3<> /dev/tcp/127.0.0.1/11211
printf "set mykey 0 60 5\r\nhello\r\nget mykey\r\nquit\r\n" >&3
response="$(timeout 10 cat <&3)"
exec 3<&-

echo "Response: $response"
[[ "$response" == *"STORED"* ]]
[[ "$response" == *"hello"* ]]
