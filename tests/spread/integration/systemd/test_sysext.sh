#!/bin/bash
#spellchecker: ignore rootfs sysext confext confexts

# What a consumer gets from systemd_sysext: the tools that find system and
# configuration extensions where the manager looks for them.

rootfs="$(install-slices systemd_sysext)"
for bin in /usr/bin/systemd-sysext /usr/bin/systemd-confext; do
  chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
done

# one of each, as a plain directory with the release file that marks it
sys="$rootfs/var/lib/extensions/chisel-sys"
conf="$rootfs/var/lib/confexts/chisel-conf"
mkdir -p "$sys/usr/lib/extension-release.d" "$conf/etc/extension-release.d"
echo "ID=_any" > "$sys/usr/lib/extension-release.d/extension-release.chisel-sys"
echo "ID=_any" > "$conf/etc/extension-release.d/extension-release.chisel-conf"

sysexts="$(chroot "$rootfs" systemd-sysext list)"
confexts="$(chroot "$rootfs" systemd-confext list)"
grep -Eq "^chisel-sys +directory +/var/lib/extensions/chisel-sys " <<<"$sysexts"
grep -Eq "^chisel-conf +directory +/var/lib/confexts/chisel-conf " <<<"$confexts"
# and each sees only its own kind
! grep -Fq "chisel-conf" <<<"$sysexts" || exit 1
! grep -Fq "chisel-sys" <<<"$confexts" || exit 1
