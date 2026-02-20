#!/usr/bin/env bash
#spellchecker: ignore rootfs bsdutils renice coreutils

rootfs="$(install-slices bsdutils_renice)"

chroot "$rootfs" /usr/bin/renice --help | grep -q "Usage:"
chroot "$rootfs" /usr/bin/renice --version | grep -q "renice"

# test altering the priority of a process
rootfs_sleep="$(install-slices bsdutils_renice coreutils_delaying dash_bins)"

# mock /dev/null
mkdir -p "$rootfs_sleep/dev" && touch "$rootfs_sleep/dev/null"

cat > "$rootfs_sleep/test_renice.sh" <<'EOF'
#!/usr/bin/sh -e
/usr/bin/sleep 10 &
sleep_pid=$!
trap "kill $sleep_pid || true" EXIT
/usr/bin/renice --priority 5 -p $sleep_pid
EOF

chmod +x "$rootfs_sleep/test_renice.sh"

chroot "$rootfs_sleep" /test_renice.sh | grep -q "old priority 0, new priority 5"
