source "$(dirname "$0")/helpers.sh"

setup core
chroot . $java -cp . Main
chroot . $java -cp / SysLookup
grep -q '^JAVA_VERSION="17' "$rootfs$(dirname $java)/../release"
