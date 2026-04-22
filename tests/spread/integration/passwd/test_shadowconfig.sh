#!/bin/bash
#spellchecker: ignore rootfs shadowconfig gshadow

rootfs="$(install-slices passwd_shadowconfig)"

# test basic help output
chroot "$rootfs" shadowconfig --help | grep -iq "usage"

cat > "$rootfs/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/bash
EOF

cat > "$rootfs/etc/group" << 'EOF'
root:x:0:
EOF

# turn on shadow passwords
! test -f "$rootfs/etc/shadow"
! test -f "$rootfs/etc/gshadow"
chroot "$rootfs" shadowconfig on
test -f "$rootfs/etc/shadow"
test -f "$rootfs/etc/gshadow"

# verify passwd and group files now have 'x' placeholders
grep -q "^root:x:" "$rootfs/etc/passwd"
grep -q "^root:x:" "$rootfs/etc/group"

# verify shadow and gshadow files contain the actual entries
grep -q "^root:" "$rootfs/etc/shadow"
grep -q "^root:" "$rootfs/etc/gshadow"

# turning off shadow passwords is no longer supported
chroot "$rootfs" shadowconfig off | grep -q "Turning shadow passwords off is no longer supported"
