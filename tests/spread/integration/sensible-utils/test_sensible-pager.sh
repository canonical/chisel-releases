#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_sensible-pager)"

mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"

chroot "$rootfs" sensible-pager 2>&1 | grep -iq "couldn't find a pager"

# if nothing is there, it should default to pager
touch "$rootfs/usr/bin/pager" && chmod +x "$rootfs/usr/bin/pager"
chroot "$rootfs" sensible-pager

# we can select the pager through the PAGER variable
cat <<'EOF' > "$rootfs/usr/bin/fake-pager"
#!/bin/sh
printf "fake-pager called with: %s\n" "$*" > /var/log/fake-pager.log
EOF
mkdir -p "$rootfs/var/log"
chmod +x "$rootfs/usr/bin/fake-pager"

PAGER=/usr/bin/fake-pager chroot "$rootfs" sensible-pager
test -f "$rootfs/var/log/fake-pager.log"
grep -q "fake-pager called with: " "$rootfs/var/log/fake-pager.log"

# SENSIBLE_PAGER is consulted after PAGER but before the fixed candidates
rm "$rootfs/var/log/fake-pager.log"
SENSIBLE_PAGER=/usr/bin/fake-pager chroot "$rootfs" sensible-pager
grep -q "fake-pager called with: " "$rootfs/var/log/fake-pager.log"

# with pager gone the list falls through to more
rm "$rootfs/usr/bin/pager"
cat <<'EOF' > "$rootfs/usr/bin/more"
#!/bin/sh
printf "more called with: %s\n" "$*" > /var/log/more.log
EOF
chmod +x "$rootfs/usr/bin/more"

chroot "$rootfs" sensible-pager
grep -q "more called with: " "$rootfs/var/log/more.log"

# a candidate pointing back at the script is refused rather than looping
rc=0; __SENSIBLE_PAGER=1 chroot "$rootfs" sensible-pager || rc=$?
test "$rc" -eq 126
