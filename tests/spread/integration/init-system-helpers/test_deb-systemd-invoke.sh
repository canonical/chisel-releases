#!/usr/bin/env bash
# spellchecker: ignore rootfs 

rootfs="$(install-slices init-system-helpers_deb-systemd-invoke )"

(chroot "$rootfs" deb-systemd-invoke --foo 2>&1 || true) | \
    grep "Syntax: /usr/bin/deb-systemd-invoke <action> \[<unit file> \[<unit file> ...\]\]"

# we're not going to be able to really start anything, but at least make sure that systemctl
# is present
chroot "$rootfs" deb-systemd-invoke start test.service 2>&1 | \
    grep -q "test.service is a disabled or a static unit, not starting it"

# mock out systemctl to check that deb-systemd-invoke is calling as expected
mkdir -p "$rootfs/usr/local/bin" "$rootfs/tmp"
cat > "$rootfs/usr/local/bin/systemctl" <<'EOF'
#!/usr/bin/perl
print "[LOG] systemctl @ARGV\n";
open(my $fh, '>>', "/tmp/mock-systemctl.log") or die;
print $fh join(' ', $0, @ARGV) . "\n";
close $fh;
EOF
chmod +x "$rootfs/usr/local/bin/systemctl"

# test mocked start
chroot "$rootfs" deb-systemd-invoke start test.service 2>&1
grep -qE "systemctl.*is-enabled.*test\.service" "$rootfs/tmp/mock-systemctl.log"
grep -qE "systemctl.*is-active.*test\.service" "$rootfs/tmp/mock-systemctl.log"
grep -qE "systemctl.*start.*test\.service" "$rootfs/tmp/mock-systemctl.log"

# test mocked restart
rm "$rootfs/tmp/mock-systemctl.log"
chroot "$rootfs" deb-systemd-invoke restart test.service 2>&1
grep -qE "systemctl.*is-active.*test\.service" "$rootfs/tmp/mock-systemctl.log"
grep -qE "systemctl.*restart.*test\.service" "$rootfs/tmp/mock-systemctl.log"

# test mocked stop
rm "$rootfs/tmp/mock-systemctl.log"
chroot "$rootfs" deb-systemd-invoke stop test.service 2>&1
grep -qE "systemctl.*stop.*test\.service" "$rootfs/tmp/mock-systemctl.log"
