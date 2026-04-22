#!/bin/bash
#spellchecker: ignore rootfs grpconv rootsalt rootencrypted testgroup groupsalt
#spellchecker: ignore groupencrypted testuser gshadow

rootfs="$(install-slices passwd_grpconv)"

# test basic help output
chroot "$rootfs" grpconv --help | grep -iq "usage"

# create a test group file with password hashes
cat > "$rootfs/etc/group" << 'EOF'
root:$6$rootsalt$rootencrypted:0:
testgroup:$6$groupsalt$groupencrypted:1000:testuser
EOF

# convert
! test -f "$rootfs/etc/gshadow"
chroot "$rootfs" grpconv
test -f "$rootfs/etc/gshadow"

# verify group file now has 'x' placeholders
grep -q "^root:x:" "$rootfs/etc/group"
grep -q "^testgroup:x:" "$rootfs/etc/group"

# verify gshadow file contains the actual passwords
grep -q "^root:\$6\$rootsalt\$rootencrypted:" "$rootfs/etc/gshadow"
grep -q "^testgroup:\$6\$groupsalt\$groupencrypted:" "$rootfs/etc/gshadow"

# test no changes if run again
hash_before=$(sha256sum "$rootfs/etc/gshadow")
chroot "$rootfs" grpconv
hash_after=$(sha256sum "$rootfs/etc/gshadow")
test "$hash_before" = "$hash_after"
