#!/bin/bash
# Tests for openssh-client's ssh-copy-id slice.

## Setup
rootfs="$(install-slices openssh-client_ssh-copy-id)"

mkdir -p "${rootfs}/dev"
touch "${rootfs}/dev/null"
mkdir "${rootfs}/tmp"

# Generate a client key and add it to the agent
mkdir -p "${rootfs}/root/.ssh"
chroot "${rootfs}"/ ssh-keygen -f /root/.ssh/id -N ''
eval "$(chroot "${rootfs}"/ ssh-agent)"
chroot "${rootfs}"/ ssh-add /root/.ssh/id

# Copy their identity over to the outer machine so they can ssh back out
# shellcheck disable=SC2174  # permission only applies to the innermost directory
mkdir -m 700 -p ~openssh-slice-test-user/.ssh
chown openssh-slice-test-user ~openssh-slice-test-user/.ssh
cp "${rootfs}"/root/.ssh/id.pub ~openssh-slice-test-user/.ssh/authorized_keys
chown openssh-slice-test-user ~openssh-slice-test-user/.ssh/authorized_keys

## Tests

# Generate another key and use ssh-copy-id to copy it over.
chroot "${rootfs}"/ ssh-keygen -f /root/.ssh/id2 -N ''
chroot "${rootfs}"/ ssh-add /root/.ssh/id2
chroot "${rootfs}"/ dash /usr/bin/ssh-copy-id -oStrictHostKeyChecking=no openssh-slice-test-user@127.0.0.1
chroot "${rootfs}"/ ssh -oStrictHostKeyChecking=no -i /root/.ssh/id2 openssh-slice-test-user@127.0.0.1 true

# Try with scp
chroot "${rootfs}"/ ssh-keygen -f /root/.ssh/id3 -N ''
chroot "${rootfs}"/ ssh-add /root/.ssh/id3
chroot "${rootfs}"/ dash /usr/bin/ssh-copy-id -oStrictHostKeyChecking=no -s openssh-slice-test-user@127.0.0.1
chroot "${rootfs}"/ ssh -oStrictHostKeyChecking=no -i /root/.ssh/id3 openssh-slice-test-user@127.0.0.1 true
