#!/bin/bash
#spellchecker: ignore rootfs dpkg

# Create a dependency-free package tree inside the rootfs under test.
make_fixture() {
    local rootfs="$1"

    # dpkg-deb needs a temporary directory when building the archive.
    mkdir -p "$rootfs/tmp" "$rootfs/fixture/DEBIAN" "$rootfs/fixture/usr/share/dpkg-fixture"
    cat > "$rootfs/fixture/DEBIAN/control" <<'EOF'
Package: dpkg-fixture
Version: 1.0
Architecture: all
Maintainer: Chisel Tests <tests@example.invalid>
Description: Locally generated dpkg integration fixture
EOF
    printf 'fixture payload\n' > "$rootfs/fixture/usr/share/dpkg-fixture/payload"
}

# Use the sliced dpkg-deb rather than a package-building tool from the host.
build_fixture() {
    local rootfs="$1"

    chroot "$rootfs" dpkg-deb --root-owner-group --build /fixture /fixture.deb
}
