#!/bin/bash
#spellchecker: ignore rootfs diffutils

# basic smoke test for dpkg without maintainer scripts
rootfs="$(install-slices dpkg_bins)"

# Get a sample deb file to install. Contains no dependencies or install scripts.
# The sliced apt fetches it from the release under test, not the test host.
apt_root="$(install-slices apt_apt-get)"
mkdir -p "$apt_root/dev" "$apt_root/debs/partial" "$rootfs/debs"
mount --bind /dev "$apt_root/dev"
cp /etc/resolv.conf "$apt_root/etc/resolv.conf"
touch "$apt_root/empty-status"
chroot "$apt_root" apt-get update
chroot "$apt_root" apt-get -o Dir::Cache::archives=/debs -o Dir::State::status=/empty-status \
  install --download-only --no-install-recommends --assume-yes lsb-release
cp "$apt_root"/debs/*.deb "$rootfs/debs/"
umount "$apt_root/dev"

# Run a smoke test for dpkg to ensure that it does not throw an error
chroot "$rootfs" dpkg --install -R /debs
