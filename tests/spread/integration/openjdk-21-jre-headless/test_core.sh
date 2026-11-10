source "$(dirname "$0")/helpers.sh"

setup core
chroot . $java /Main.java
chroot . $java -cp / SysLookup
grep -q '^JAVA_VERSION="21' "$rootfs$(dirname $java)/../release"
