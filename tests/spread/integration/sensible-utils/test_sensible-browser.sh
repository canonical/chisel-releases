#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_sensible-browser)"

mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"

chroot "$rootfs" sensible-browser 2>&1 | grep -iq "couldn't find a suitable web browser"

# if nothing is there, it should default to www-browser
touch "$rootfs/usr/bin/www-browser" && chmod +x "$rootfs/usr/bin/www-browser"
chroot "$rootfs" sensible-browser

# we can select the browser through the BROWSER variable
cat <<'EOF' > "$rootfs/usr/bin/fake-browser"
#!/bin/sh
printf "fake-browser called with: %s\n" "$*" > /var/log/fake-browser.log
EOF
mkdir -p "$rootfs/var/log"
chmod +x "$rootfs/usr/bin/fake-browser"

BROWSER=/usr/bin/fake-browser chroot "$rootfs" sensible-browser
test -f "$rootfs/var/log/fake-browser.log"
grep -q "fake-browser called with: " "$rootfs/var/log/fake-browser.log"
