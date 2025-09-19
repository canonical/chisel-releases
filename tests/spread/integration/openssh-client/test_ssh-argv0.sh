#!/bin/bash
# Tests for openssh-client's ssh-argv0 slice.

## Setup
rootfs="$(install-slices openssh-client_ssh-argv0)"

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

ln -s usr/bin/ssh-argv0 "${rootfs}/openssh-slice-test-user@127.0.0.1"
chroot "${rootfs}"/ dash /usr/bin/ssh-argv0 |& MATCH 'This script should not be run like this'
chroot "${rootfs}"/ dash /openssh-slice-test-user@127.0.0.1 -oStrictHostKeyChecking=no -i /root/.ssh/id2 true
