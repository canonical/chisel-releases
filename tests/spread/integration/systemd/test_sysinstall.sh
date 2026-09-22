#!/bin/bash
#spellchecker: ignore rootfs sysinstall repart logind nsrun nsystemctl devtmpfs
#spellchecker: ignore osrel partscan objcopy

# What systemd_sysinstall adds: an installer, and the target an installer
# medium boots into to run it. The installer copies the running system onto a
# disk with systemd-repart and makes it bootable with bootctl.

# shellcheck source=tests/spread/integration/systemd/helpers.sh
. ./helpers.sh

# the slice on its own carries what its own programs need
rootfs="$(install-slices systemd_sysinstall)"
for bin in /usr/bin/systemd-sysinstall /usr/bin/systemd-creds /usr/lib/systemd/systemd-logind; do
  chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
done
clean-rootfs "$rootfs"

# the target pulls the installer in, and its unit runs it
rootfs="$(install-slices systemd_sysinstall systemd_core dbus_services)"

# the unit wants a console, and a failed install would halt the manager
mkdir -p "$rootfs/etc/systemd/system/systemd-sysinstall.service.d"
cat > "$rootfs/etc/systemd/system/systemd-sysinstall.service.d/override.conf" <<'EOF'
[Service]
StandardInput=null
StandardOutput=journal
StandardError=journal
TTYReset=no
FailureAction=none
EOF

trap 'shutdown_rootfs || true' EXIT
boot_rootfs "$rootfs"
# shellcheck disable=SC2119 # nothing in this closure is expected to fail
assert_failed_units

nsystemctl start system-install.target
for _ in $(seq 1 20); do
  state="$(nsystemctl show -p ActiveState --value systemd-sysinstall.service)"
  [ "$state" = "failed" ] && break
  sleep 0.5
done
nsystemctl is-active systemd-logind.service

shutdown_rootfs
clean-rootfs "$rootfs"

# TODO: uncomment once systemd-repart, systemd-boot-tools, systemd-boot-efi,
# e2fsprogs and binutils are sliced
#
# # a medium boots into the target, installs itself onto a disk, and what it
# # installed boots. sd-boot exists on EFI architectures only
# case "$(dpkg --print-architecture)" in
#   amd64 | arm64) ;;
#   *) exit 0 ;;
# esac
#
# tools="$(install-slices binutils_objcopy mount_bins systemd-boot-efi_stubs)"
# rootfs="$(install-slices systemd_sysinstall systemd_core dbus_services \
#   dosfstools_mkfs e2fsprogs_mkfs mount_bins)"
# echo "ID=chisel" > "$rootfs/usr/lib/os-release"
#
# # a UKI: the stub, with an os-release and a stand-in kernel past its image
# stub="$(cd "$tools" && echo usr/lib/systemd/boot/efi/linux*.efi.stub)"
# pe="$(od -An -tu4 -j 60 -N 4 "$tools/$stub")"              # e_lfanew
# base="$(od -An -tu8 -j $((pe + 48)) -N 8 "$tools/$stub")"  # ImageBase
# size="$(od -An -tu4 -j $((pe + 80)) -N 4 "$tools/$stub")"  # SizeOfImage
# cp "$rootfs/usr/lib/os-release" "$tools/os-release"
# echo "not a kernel" > "$tools/linux"
# chroot "$tools" objcopy \
#   --add-section .osrel=/os-release --change-section-vma .osrel=$((base + size)) \
#   --add-section .linux=/linux --change-section-vma .linux=$((base + size + 0x1000)) \
#   "/$stub" /chisel.efi
# mkdir -p "$rootfs/var/tmp"
# cp "$tools/chisel.efi" "$rootfs/var/tmp/"
# truncate -s 1G "$rootfs/var/tmp/disk.img"
#
# mkdir -p "$rootfs/usr/lib/repart.sysinstall.d"
# printf '[Partition]\nType=esp\nFormat=vfat\n' > "$rootfs/usr/lib/repart.sysinstall.d/10-esp.conf"
# printf '[Partition]\nType=root\nFormat=ext4\nCopyFiles=/\nExcludeFiles=/var/tmp/\n' \
#   > "$rootfs/usr/lib/repart.sysinstall.d/20-root.conf"
#
# # the answers to the prompts, and a devtmpfs for the new partitions' nodes
# mkdir -p "$rootfs/etc/systemd/system/systemd-sysinstall.service.d"
# cat > "$rootfs/etc/systemd/system/systemd-sysinstall.service.d/override.conf" <<'EOF'
# [Service]
# StandardInput=null
# StandardOutput=journal
# StandardError=journal
# TTYReset=no
# FailureAction=none
# ExecStart=
# ExecStart=systemd-sysinstall --welcome=no --chrome=no --confirm=no --summary=no \
#   --erase=yes --variables=no --reboot=no --mute-console=no --copy-locale=no \
#   --copy-keymap=no --copy-timezone=no --kernel=/var/tmp/chisel.efi /var/tmp/disk.img
# BindPaths=/run/devtmpfs:/dev
# EOF
#
# boot_rootfs "$rootfs"
# nsrun mount --mkdir -t devtmpfs devtmpfs /run/devtmpfs
# nsystemctl start system-install.target
# for _ in $(seq 1 240); do
#   nsystemctl is-active -q systemd-sysinstall.service || break
#   sleep 0.5
# done
# test "$(nsystemctl show -p Result --value systemd-sysinstall.service)" = "success"
# shutdown_rootfs
#
# # read-only: a delete in a devtmpfs deletes the host's device nodes
# mkdir -p "$tools"/{dev,target,esp,root}
# mount -t devtmpfs -o ro devtmpfs "$tools/dev"
# mount --bind "$rootfs/var/tmp" "$tools/target"
# loop="$(chroot "$tools" losetup --find --show --partscan /target/disk.img)"
# trap 'chroot "$tools" losetup -d "$loop"; umount "$tools/dev"; shutdown_rootfs || true' EXIT
#
# chroot "$tools" mount -o ro "${loop}p1" /esp
# grep -Eq '^uki /[^/]+/chisel\.efi$' "$tools"/esp/loader/entries/*.conf
# test -f "$tools"/esp/EFI/BOOT/BOOT*.EFI
# chroot "$tools" umount /esp
#
# chroot "$tools" mount "${loop}p2" /root
# boot_rootfs "$tools/root"
# # shellcheck disable=SC2119 # nothing in this closure is expected to fail
# assert_failed_units
# shutdown_rootfs
