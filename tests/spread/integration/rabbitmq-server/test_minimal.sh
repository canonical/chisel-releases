#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer gets from rabbitmq-server_minimal: a broker that boots with
# no plugins and serves AMQP, and nothing to manage it with.

# shellcheck source=tests/spread/integration/rabbitmq-server/helpers.sh
. ./helpers.sh

rootfs="$(install-slices rabbitmq-server_minimal)"

start_broker "$rootfs"
grep -q 'Server startup complete; 0 plugins started' "$rootfs/broker.log"
assert_amqp

# stops on SIGTERM, and nothing in the log went wrong on the way
stop_broker "$rootfs"
if grep -q '\[error\]' "$rootfs/broker.log"; then
  exit 1
fi
