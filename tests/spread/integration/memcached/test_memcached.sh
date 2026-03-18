#!/bin/bash

# Ensure the host has the networking tools required for the test  
apt-get update && apt-get install -y iproute2 netcat-openbsd

rootfs="$(install-slices memcached_bins base-passwd_data)"

chroot "$rootfs" memcached -V

# Verify it can start and listen on the default port (11211)
chroot "$rootfs" memcached -u root -d -P /memcached.pid

trap "kill $(cat $rootfs/memcached.pid) || true" EXIT

# Wait for the port to be available with retry logic
attempts=0
max_attempts=10
while [ $attempts -lt $max_attempts ]; do
    if ss -tulpn | grep :11211 > /dev/null; then
        echo "Port 11211 is open"
        break
    fi
    attempts=$((attempts + 1))
    echo "Attempt $attempts/$max_attempts: waiting for port 11211..."
    sleep 1
done

if [ $attempts -eq $max_attempts ]; then
    echo "Failed to detect memcached listening on port 11211 after $max_attempts attempts"
    exit 1
fi

# Set and Get a key
# Protocol: set <key> <flags> <exptime> <bytes>\r\n<value>\r\n
echo "Writing to memcached..."
printf "set mykey 0 60 5\r\nhello\r\n" > /dev/tcp/127.0.0.1/11211

# Protocol: get <key>\r\n
echo "Reading from memcached..."

RESPONSE=$(printf "get mykey\r\n" | nc -q 1 127.0.0.1 11211)

# Check if we got the expected response
echo "Response: $RESPONSE"
if [[ "$RESPONSE" == *"hello"* ]]; then
    echo "SUCCESS: Retrieved value from memcached"
else
    echo "FAILED: Did not get expected response from memcached"
    exit 1
fi