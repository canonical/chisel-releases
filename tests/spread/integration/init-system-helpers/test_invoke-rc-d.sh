#!/usr/bin/env bash
# spellchecker: ignore rootfs initscript runlevel

rootfs="$(install-slices init-system-helpers_invoke-rc-d)"

mkdir -p "$rootfs/tmp"

# test help
chroot "$rootfs" /usr/sbin/invoke-rc.d --help | \
    grep -q "invoke-rc.d \[options\] <basename> <action> \[extra parameters\]"

# test with missing initscript
out=$(chroot "$rootfs" /usr/sbin/invoke-rc.d test start 2>&1 || true)
echo "$out" | grep -q "unknown initscript, /etc/init.d/test not found"
echo "$out" | grep -q "could not determine current runlevel"

# make dummy initscript
mkdir -p "$rootfs/etc/init.d"
cat > "$rootfs/etc/init.d/test" <<'EOF'
#!/bin/sh
echo "[LOG] $0 $@"
echo "$0 $@" >> /tmp/test.log
exit 0
EOF
chmod +x "$rootfs/etc/init.d/test"

chroot "$rootfs" /usr/sbin/invoke-rc.d test start 2>&1 || true | \
    grep -q " WARNING: No init system and policy-rc.d missing! Defaulting to block."

# mock policy-rc.d to allow the action
printf '#!/bin/sh\nexit 0\n' > "$rootfs/usr/sbin/policy-rc.d"
chmod +x "$rootfs/usr/sbin/policy-rc.d"

# now we should start
chroot "$rootfs" /usr/sbin/invoke-rc.d test start 2>&1 || true
cat "$rootfs/tmp/test.log" | grep -q "/etc/init.d/test start"
