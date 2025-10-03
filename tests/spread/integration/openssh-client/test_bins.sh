#!/bin/bash
# Tests for openssh-client binaries.

## Setup
rootfs="$(install-slices openssh-client_bins)"

mkdir -p "${rootfs}/dev"
touch "${rootfs}/dev/null"
mkdir "${rootfs}/tmp"

##Tests
# Scan the local ssh server for a key.
chroot "${rootfs}"/ ssh-keyscan 127.0.0.1

# Generate a client key
mkdir -p "${rootfs}/root/.ssh"
chroot "${rootfs}"/ ssh-keygen -f /root/.ssh/id -N ''

# Start an agent in the chroot and bring its auth socket and pid to the environment
eval "$(chroot "${rootfs}"/ ssh-agent)"

chroot "${rootfs}"/ ssh-add -L | MATCH 'The agent has no identities.'
chroot "${rootfs}"/ ssh-add /root/.ssh/id
diff "${rootfs}/root/.ssh/id.pub" <(chroot "${rootfs}/" ssh-add -L)

# Copy their identity over to the outer machine so they can ssh back out
# shellcheck disable=SC2174  # permission only applies to the innermost directory
mkdir -m 700 -p ~openssh-slice-test-user/.ssh
chown openssh-slice-test-user ~openssh-slice-test-user/.ssh
cp "${rootfs}"/root/.ssh/id.pub ~openssh-slice-test-user/.ssh/authorized_keys
chown openssh-slice-test-user ~openssh-slice-test-user/.ssh/authorized_keys

# Does the ssh binary actually work?
chroot "${rootfs}"/ ssh -oStrictHostKeyChecking=no -i /root/.ssh/id openssh-slice-test-user@127.0.0.1 true

# Now try scp and sftp
echo "I am going to scp this" > "${rootfs}/scp-file"
chroot "${rootfs}"/ scp -i /root/.ssh/id /scp-file openssh-slice-test-user@127.0.0.1:~/scp-done
test -f ~openssh-slice-test-user/scp-done
diff -q "${rootfs}/scp-file" ~openssh-slice-test-user/scp-done

echo "I am going to sftp this" > "${rootfs}/sftp-file"
echo "put sftp-file" > "${rootfs}/sftp-commands"
chroot "${rootfs}"/ sftp -i /root/.ssh/id -b /sftp-commands openssh-slice-test-user@127.0.0.1
test -f ~openssh-slice-test-user/sftp-file
diff -q "${rootfs}/sftp-file" ~openssh-slice-test-user/sftp-file
