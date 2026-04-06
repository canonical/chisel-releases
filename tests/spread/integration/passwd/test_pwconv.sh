#!/bin/bash
#spellchecker: ignore rootfs pwconv

rootfs="$(install-slices passwd_pwconv)"

# test basic help output
chroot "$rootfs" pwconv --help | grep -iq "usage"

# create a test passwd file with password hashes
cat > "$rootfs/etc/passwd" << 'EOF'
root:$6$salt$encryptedpassword:0:0:root:/root:/bin/bash
testuser:$6$anothersalt$anotherpassword:1000:1000:Test User:/home/testuser:/bin/bash
nobody:!:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
EOF


# convert
! test -f "$rootfs/etc/shadow"
chroot "$rootfs" pwconv
test -f "$rootfs/etc/shadow"

# verify passwd file now has 'x' placeholders
grep -q "^root:x:" "$rootfs/etc/passwd"
grep -q "^testuser:x:" "$rootfs/etc/passwd"
grep -q "^nobody:x:" "$rootfs/etc/passwd"

# verify shadow file contains the actual passwords
grep -q "^root:\$6\$salt\$encryptedpassword:" "$rootfs/etc/shadow"
grep -q "^testuser:\$6\$anothersalt\$anotherpassword:" "$rootfs/etc/shadow"
grep -q "^nobody:!:" "$rootfs/etc/shadow"

# test no changes if run again
hash_before=$(sha256sum "$rootfs/etc/shadow")
chroot "$rootfs" pwconv
hash_after=$(sha256sum "$rootfs/etc/shadow")
test "$hash_before" = "$hash_after"
