#!/usr/bin/env bash
# spellchecker: ignore rootfs

rootfs="$(install-slices init-system-helpers_service)"

chroot "$rootfs" /usr/sbin/service --help 2>&1 | grep -q "Usage: service"
chroot "$rootfs" /usr/sbin/service --version 2>&1 | grep -q "service ver."

# Status without any services
mkdir -p "$rootfs/etc/init.d"
out=$(chroot "$rootfs" /usr/sbin/service --status-all)
test -z "$out"

# make a test service
service="$rootfs/etc/init.d/test"
cat > "$service" <<'EOF'
#!/bin/sh
echo "hello from test service"
exit 0
EOF
chmod +x "$service"

# test service healthy
chroot "$rootfs" /usr/sbin/service --status-all 2>&1 | \
    grep -Eq "\s*[ + ]\s*test"

# test service unhealthy
sed -i 's/exit 0/exit 1/' "$service"
chroot "$rootfs" /usr/sbin/service --status-all 2>&1 | \
    grep -Eq "\s*[ - ]\s*test"

# test service unknown
sed -i 's/echo.*/echo "usage: test {foo|bar}"/' "$service"
chmod +x "$service"
chroot "$rootfs" /usr/sbin/service --status-all 2>&1 | \
    grep -Eq "\s*[ ? ]\s*test"

# test start
sed -i 's/exit 1/exit 0/' "$service"
sed -i 's/echo.*/echo "hello from test service"/' "$service"
cat "$service"
chroot "$rootfs" /usr/sbin/service test start 2>&1 | grep -q "hello from test service"
