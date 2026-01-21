# Install slices
rootfs="$(install-slices apache2_standard base-files_base base-passwd_data)"

# Mount dev into the chroot
mkdir -p "${rootfs}/dev"
mount --rbind /dev "${rootfs}/dev"

# Create required directories
mkdir -p "$rootfs/run/apache2"
mkdir -p "$rootfs/var/www/html"

# Allow apache2 traverse path to DocumentRoot
chmod 755 "$rootfs"

# Clean up any process using port 80
fuser -k 80/tcp || true

# Switch the mpm to prefork to prevent threading issues in tests
# (mpm_event causes a coredump and can't locate libgcc_s.so.1)
chroot "$rootfs" /usr/sbin/a2dismod mpm_event
chroot "$rootfs" /usr/sbin/a2enmod mpm_prefork

# Verify the new mpm is correctly enabled (test a2query script)
chroot "$rootfs" /usr/sbin/a2query -m mpm_prefork | grep "mpm_prefork (enabled by"
! chroot "$rootfs" /usr/sbin/a2query -m | grep "mpm_event"

# Use configtest utility to verify configuration
chroot "$rootfs" /usr/sbin/apache2ctl configtest

# Trap the apachectl stop on exit
trap 'chroot "$rootfs" /usr/sbin/apachectl stop 2>/dev/null || true' EXIT

# Start apache2 via apachectl
chroot "$rootfs" /usr/sbin/apachectl start
sleep 2

# Test the default page is present
curl -s http://127.0.0.1/index.html

# Test the restart script
chroot "$rootfs" /usr/sbin/apachectl restart
sleep 2

# Check the page still works after restart
curl -s http://127.0.0.1/index.html

# Test the rest of the scripts
chroot "$rootfs" /usr/sbin/a2query -s 000-default
chroot "$rootfs" /usr/sbin/a2dissite 000-default
! chroot "$rootfs" /usr/sbin/a2query -s | grep "000-default"

chroot "$rootfs" /usr/sbin/a2query -c charset
chroot "$rootfs" /usr/sbin/a2disconf charset
! chroot "$rootfs" /usr/sbin/a2query -c | grep "charset"
