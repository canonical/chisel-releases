#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer gets from rabbitmq-server_config: the stock env file, which
# sets nothing, readable by the rabbitmq user.

rootfs="$(install-slices rabbitmq-server_config)"

conf="$rootfs/etc/rabbitmq/rabbitmq-env.conf"
test "$(stat -c %a "$conf")" = 644
if grep -qvE '^\s*(#|$)' "$conf"; then
  exit 1
fi
