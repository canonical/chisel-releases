source "$(dirname "$0")/helpers.sh"

setup core
chroot . $java /Main.java
