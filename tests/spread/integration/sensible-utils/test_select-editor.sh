#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices sensible-utils_select-editor)"

mkdir -p "$rootfs/dev" && touch "$rootfs/dev/null"
mkdir -p "$rootfs/root" && touch "$rootfs/root/.selected_editor"

chroot "$rootfs" select-editor 2>&1 | grep -iq "no alternatives for editor"

for e in nano vim; do
    echo "#!/bin/sh" > "$rootfs/usr/bin/$e"
    chmod +x "$rootfs/usr/bin/$e"
done
chroot "$rootfs" update-alternatives --install /usr/bin/editor editor /usr/bin/vim 50
chroot "$rootfs" update-alternatives --install /usr/bin/editor editor /usr/bin/nano 30

# the menu is ordered by descending priority, and nano is always singled out
# no matter where it lands in that order
chroot "$rootfs" select-editor < /dev/null > /tmp/output 2>&1
grep -q "1\. /usr/bin/vim" /tmp/output
grep -q "2\. /usr/bin/nano" /tmp/output
grep -q "easiest" /tmp/output

# an empty answer takes the default, which is nano rather than the top entry
grep -q 'SELECTED_EDITOR="/usr/bin/nano"' "$rootfs/root/.selected_editor"

echo 1 | chroot "$rootfs" select-editor > /dev/null 2>&1
grep -q 'SELECTED_EDITOR="/usr/bin/vim"' "$rootfs/root/.selected_editor"

# and the recorded choice comes back marked
echo 1 | chroot "$rootfs" select-editor > /tmp/output 2>&1
grep -q "^\* 1\. /usr/bin/vim" /tmp/output
