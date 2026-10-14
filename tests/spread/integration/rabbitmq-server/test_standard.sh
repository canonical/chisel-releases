#!/bin/bash
#spellchecker: ignore rootfs

# What rabbitmq-server_standard adds on top of core: the optional plugins,
# complete with their dependencies, so a plugin enabled offline comes up with
# the broker.

# shellcheck source=tests/spread/integration/rabbitmq-server/helpers.sh
. ./helpers.sh

rootfs="$(install-slices rabbitmq-server_standard)"
assert_app_closure "$rootfs"
bind_kernel_fs "$rootfs"

# a plugin can be enabled before the broker ever ran
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmq-plugins enable --offline rabbitmq_management

start_broker "$rootfs"
grep -Eq 'Server startup complete; [1-9][0-9]* plugins started' "$rootfs/broker.log"
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmq-plugins -q list --enabled --minimal | grep -qx rabbitmq_management
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmq-diagnostics check_port_listener 15672
http_status /api/overview 15672 | grep -q ' 200 '
assert_amqp

stop_broker "$rootfs"
