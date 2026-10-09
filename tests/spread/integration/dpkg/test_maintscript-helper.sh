#!/bin/bash
#spellchecker: ignore rootfs dpkg maintscript conffile

rootfs="$(install-slices dpkg_maintscript-helper)"

chroot "$rootfs" dpkg-maintscript-helper --help | grep -q "^Usage: dpkg-maintscript-helper"

# it checks its commands against the dpkg in the rootfs
export DPKG_MAINTSCRIPT_NAME=postinst DPKG_MAINTSCRIPT_PACKAGE=example
chroot "$rootfs" dpkg-maintscript-helper supports rm_conffile
chroot "$rootfs" dpkg-maintscript-helper supports dir_to_symlink
