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
