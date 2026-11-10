source "$(dirname "$0")/helpers.sh"

setup core
chroot . $java -cp . Main
grep -q '^JAVA_VERSION="11' "$rootfs$(dirname $java)/../release"
