#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_sensible-terminal)"

mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"

chroot "$rootfs" sensible-terminal 2>&1 | grep -iq "couldn't find a terminal emulator"

# if nothing is there, it should default to x-terminal-emulator
touch "$rootfs/usr/bin/x-terminal-emulator" && chmod +x "$rootfs/usr/bin/x-terminal-emulator"
chroot "$rootfs" sensible-terminal

# we can select the terminal through the TERMINAL_EMULATOR variable
cat <<'EOF' > "$rootfs/usr/bin/fake-terminal"
#!/bin/sh
printf "fake-terminal called with: %s\n" "$*" > /var/log/fake-terminal.log
EOF
mkdir -p "$rootfs/var/log"
chmod +x "$rootfs/usr/bin/fake-terminal"

TERMINAL_EMULATOR=/usr/bin/fake-terminal chroot "$rootfs" sensible-terminal
test -f "$rootfs/var/log/fake-terminal.log"
grep -q "fake-terminal called with: " "$rootfs/var/log/fake-terminal.log"