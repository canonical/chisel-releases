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

# under a graphical session x-www-browser is tried ahead of www-browser
cat <<'EOF' > "$rootfs/usr/bin/x-www-browser"
#!/bin/sh
printf "x-www-browser called with: %s\n" "$*" > /var/log/x-www-browser.log
EOF
chmod +x "$rootfs/usr/bin/x-www-browser"

DISPLAY=:0 chroot "$rootfs" sensible-browser
grep -q "x-www-browser called with: " "$rootfs/var/log/x-www-browser.log"

# a candidate pointing back at the script is refused rather than looping
rc=0; __SENSIBLE_BROWSER=1 chroot "$rootfs" sensible-browser || rc=$?
test "$rc" -eq 126
