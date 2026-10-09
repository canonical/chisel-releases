#!/bin/bash
#spellchecker: ignore rootfs dpkg maintscript coreutils preinst postinst prerm postrm

. ./helpers.sh

# Exercise the shell, coreutils, and sed supplied for maintainer scripts.
rootfs="$(install-slices dpkg_maintscript-support)"
make_fixture "$rootfs"

cat > "$rootfs/fixture/DEBIAN/preinst" <<'EOF'
#!/bin/sh
set -e
mkdir -p /var/lib/dpkg-fixture
printf 'preinst %s\n' "$1" >> /var/lib/dpkg-fixture/hooks
EOF
cat > "$rootfs/fixture/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
cp /usr/share/dpkg-fixture/payload /var/lib/dpkg-fixture/copied
sed -i 's/fixture/maintscript/' /var/lib/dpkg-fixture/copied
ln -s copied /var/lib/dpkg-fixture/link
printf 'postinst %s\n' "$1" >> /var/lib/dpkg-fixture/hooks
EOF
cat > "$rootfs/fixture/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
printf 'prerm %s\n' "$1" >> /var/lib/dpkg-fixture/hooks
EOF
cat > "$rootfs/fixture/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
rm -f /var/lib/dpkg-fixture/copied /var/lib/dpkg-fixture/link
printf 'postrm %s\n' "$1" >> /var/lib/dpkg-fixture/hooks
EOF
chmod 755 "$rootfs/fixture/DEBIAN/"{preinst,postinst,prerm,postrm}
build_fixture "$rootfs"

chroot "$rootfs" dpkg --install /fixture.deb
test "$(chroot "$rootfs" dpkg-query -W -f="\${Status}" dpkg-fixture)" = 'install ok installed'
test -L "$rootfs/var/lib/dpkg-fixture/link"
test "$(cat "$rootfs/var/lib/dpkg-fixture/link")" = 'maintscript payload'
test "$(cat "$rootfs/var/lib/dpkg-fixture/hooks")" = $'preinst install\npostinst configure'

chroot "$rootfs" dpkg --remove dpkg-fixture
test ! -e "$rootfs/usr/share/dpkg-fixture/payload"
test ! -e "$rootfs/var/lib/dpkg-fixture/copied"
test ! -L "$rootfs/var/lib/dpkg-fixture/link"
test "$(cat "$rootfs/var/lib/dpkg-fixture/hooks")" = $'preinst install\npostinst configure\nprerm remove\npostrm remove'
