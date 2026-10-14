#!/bin/bash
#spellchecker: ignore rootfs

# What rabbitmq-server_core adds on top of minimal: the tools, to wait for the
# broker, inspect it and manage its users, next to it or from another rootfs.

# shellcheck source=tests/spread/integration/rabbitmq-server/helpers.sh
. ./helpers.sh

rootfs="$(install-slices rabbitmq-server_core)"
bind_kernel_fs "$rootfs"

# every tool the slice ships answers without a node
tools="$(cli_tools rabbitmq-server_core)"
test -n "$tools"
for tool in $tools; do
  chroot "$rootfs" "/usr/lib/rabbitmq/bin/$tool" help | grep -q '^Usage'
done
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl version | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+'
if chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmq-diagnostics check_running; then
  exit 1
fi

start_broker "$rootfs"
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl await_startup
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl status | grep -q '^RabbitMQ version: '
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmq-diagnostics check_running
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmq-diagnostics check_port_connectivity
assert_amqp

# the broker still has no plugins, and the tools know
if chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmq-plugins -q list --enabled --minimal | grep -q '^rabbitmq_'; then
  exit 1
fi

chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl add_user alice secret
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl set_permissions -p / alice '.*' '.*' '.*'
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl list_permissions -p / | grep -q '^alice'
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl authenticate_user alice secret
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl delete_user alice

chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl stop
stop_broker "$rootfs"

# the same tools manage a broker that runs out of a minimal rootfs
broker="$(install-slices rabbitmq-server_minimal)"
start_broker "$broker"
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmq-diagnostics check_running
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl list_users | grep -q '^guest'
chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmqctl stop
stop_broker "$broker"
