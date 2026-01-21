# Install slices
rootfs="$(install-slices apache2_core base-files_base base-passwd_data)"

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

# Add a simple index.html
echo "<html><body><h1>It works!</h1></body></html>" > "$rootfs/var/www/html/index.html"

# Manually switch to mpm_prefork to avoid threading issues in tests
# (mpm_event causes a coredump and can't locate libgcc_s.so.1)
rm -f "$rootfs/etc/apache2/mods-enabled/mpm_event.load"
rm -f "$rootfs/etc/apache2/mods-enabled/mpm_event.conf"
ln -s ../mods-available/mpm_prefork.load "$rootfs/etc/apache2/mods-enabled/mpm_prefork.load"
ln -s ../mods-available/mpm_prefork.conf "$rootfs/etc/apache2/mods-enabled/mpm_prefork.conf"

# Manually export envvars and run apache2
env -i bash -c '
    . "'"$rootfs"'/etc/apache2/envvars"
    exec chroot "'"$rootfs"'" /usr/sbin/apache2 -k start
'
sleep 2

# Trap to ensure apache2 is killed on exit
trap 'chroot "$rootfs" /usr/sbin/apache2 -k stop 2>/dev/null || true' EXIT

# Test apache2 is running by checking the default page
curl -s http://127.0.0.1/index.html | grep "It works!"
