#!/bin/bash
#spellchecker: ignore rootfs sulogin

rootfs="$(install-slices util-linux_login)"

# create fake /etc/passwd
mkdir -p "$rootfs"/etc
cat > "$rootfs"/etc/passwd << EOF
root:x:0:0:root:/root:/bin/bash
EOF

# sulogin expects keyboard inputs to continue or exit
# set timeout to let it exit without keyboard inputs after 1 second
chroot "$rootfs" sulogin --timeout 1
