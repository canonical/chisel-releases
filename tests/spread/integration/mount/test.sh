#!/bin/bash

# simple smoke test that it loads
mount --help

cat > /etc/fstab <<EOF
# test on a chrooted env, but let us make sure it exists
EOF

# Do not do the actually mounting syscall as that will
# be blocked inside the docker container. We do dry-runs
# instead to ensure that the rest of the binary looks ok
mkdir /test-bin
mount --fake --bind /bin /test-bin

# we cannot test the 'mount -l' without mounting /proc
# as it is a symlink from /etc/mtab to ../proc/self/mounts
