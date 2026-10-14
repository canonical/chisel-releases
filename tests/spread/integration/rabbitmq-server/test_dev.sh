#!/bin/bash
#spellchecker: ignore rootfs useradd nodename vmware

# What rabbitmq-server_dev adds on top of standard: the /usr/sbin wrappers that
# run everything as the rabbitmq user, as the debian package does.

# shellcheck source=tests/spread/integration/rabbitmq-server/helpers.sh
. ./helpers.sh

rootfs="$(install-slices rabbitmq-server_dev)"
bind_kernel_fs "$rootfs"

chroot "$rootfs" useradd --system --home-dir /var/lib/rabbitmq --shell /bin/sh rabbitmq
chroot "$rootfs" chown -R rabbitmq /var/lib/rabbitmq /var/log/rabbitmq /etc/rabbitmq

# as root, the wrappers switch to the rabbitmq user; a detached broker needs a
# moment before the node is there to be asked
chroot "$rootfs" /usr/sbin/rabbitmq-server -detached
for _ in $(seq 1 300); do
  chroot "$rootfs" /usr/sbin/rabbitmq-diagnostics check_running && break
  sleep 1
done
chroot "$rootfs" /usr/sbin/rabbitmqctl await_startup
chroot "$rootfs" /usr/sbin/rabbitmqctl status | grep -q '^RabbitMQ version: '
chroot "$rootfs" /usr/sbin/rabbitmq-queues --help | grep -q '^Usage'
chroot "$rootfs" /usr/sbin/rabbitmq-streams --help | grep -q '^Usage'
chroot "$rootfs" /usr/sbin/rabbitmq-upgrade --help | grep -q '^Usage'
chroot "$rootfs" /usr/sbin/rabbitmq-plugins -q list --minimal | grep -qx rabbitmq_management
chroot "$rootfs" /usr/lib/rabbitmq/bin/vmware-rabbitmq help | grep -q '^Usage'
chroot "$rootfs" /usr/sbin/rabbitmqctl stop
chroot "$rootfs" /usr/bin/epmd -kill >/dev/null 2>&1 || true

# the broker ran as rabbitmq, not as root; the user only exists in the rootfs
uid="$(awk -F: '$1 == "rabbitmq" {print $3}' "$rootfs/etc/passwd")"
test -n "$uid"
test "$(stat -c %u "$rootfs/var/lib/rabbitmq/mnesia/$RABBITMQ_NODENAME")" = "$uid"
