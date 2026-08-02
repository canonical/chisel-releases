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

# the desktop name is lowercased to build a per-desktop candidate
cat <<'EOF' > "$rootfs/usr/bin/sensible-terminal-gnome"
#!/bin/sh
printf "gnome terminal called with: %s\n" "$*" > /var/log/xdg-terminal.log
EOF
chmod +x "$rootfs/usr/bin/sensible-terminal-gnome"

XDG_CURRENT_DESKTOP=GNOME chroot "$rootfs" sensible-terminal
grep -q "gnome terminal called with: " "$rootfs/var/log/xdg-terminal.log"

# a candidate pointing back at the script is refused rather than looping
rc=0; __SENSIBLE_TERMINAL=1 chroot "$rootfs" sensible-terminal || rc=$?
test "$rc" -eq 126
