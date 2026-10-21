source "$(dirname "$0")/helpers.sh"

setup awt
chroot . $java /ImageTest.java
file -i HelloWorld.png | grep -q "image/png; charset=binary"
