#!/bin/bash
# spellchecker: ignore rootfs

rootfs="$(install-slices iptables_scripts)"

mkdir -p "$rootfs"/dev
touch "$rootfs"/dev/null

chroot "$rootfs" iptables-apply --help 2>&1 | grep -iq "usage"

# Test --version
chroot "$rootfs" iptables-apply --version 2>&1 | grep -iq "iptables-apply 1.1"

# Test command option with a simple command (since we can't test real iptables)
# Use a command that succeeds immediately
mkdir -p "$rootfs"/tmp
echo '#!/bin/bash
echo "Command executed"
' > "$rootfs"/tmp/test_cmd.sh
chmod +x "$rootfs"/tmp/test_cmd.sh

# This will prompt for confirmation, but since it's non-interactive, it should timeout
# We capture the output to check it runs the command
chroot "$rootfs" iptables-apply -t 5 -c /tmp/test_cmd.sh 2>&1 | grep -q "Command executed"

# Test with a rules file (create a dummy one)
echo "# Dummy rules file
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
COMMIT
" > "$rootfs"/tmp/test_rules

# Again, this will prompt and timeout, but check it reads the file
chroot "$rootfs" iptables-apply -t 5 /tmp/test_rules 2>&1 | \
    grep -q "Applying new iptables rules from '/tmp/test_rules'..."
