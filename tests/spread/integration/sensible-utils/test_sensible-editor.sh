#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_sensible-editor)"

mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"

chroot "$rootfs" sensible-editor 2>&1 | grep -iq "couldn't find an editor"

# if nothing is there, it should default to editor
touch "$rootfs/usr/bin/editor" && chmod +x "$rootfs/usr/bin/editor"
chroot "$rootfs" sensible-editor

# we can select the editor through the EDITOR variable
cat <<'EOF' > "$rootfs/usr/bin/fake-editor"
#!/bin/sh
printf "fake-editor called with: %s\n" "$*" > /var/log/fake-editor.log
EOF
mkdir -p "$rootfs/var/log"
chmod +x "$rootfs/usr/bin/fake-editor"

EDITOR=/usr/bin/fake-editor chroot "$rootfs" sensible-editor
test -f "$rootfs/var/log/fake-editor.log"
grep -q "fake-editor called with: " "$rootfs/var/log/fake-editor.log"

# a choice recorded by select-editor is picked up ahead of the fallback list
mkdir -p "$rootfs/root"
echo 'SELECTED_EDITOR="/usr/bin/fake-editor"' > "$rootfs/root/.selected_editor"
rm "$rootfs/var/log/fake-editor.log"
chroot "$rootfs" sensible-editor
grep -q "fake-editor called with: " "$rootfs/var/log/fake-editor.log"

# a candidate pointing back at the script is refused rather than looping
rc=0; __SENSIBLE_EDITOR=1 chroot "$rootfs" sensible-editor || rc=$?
test "$rc" -eq 126
