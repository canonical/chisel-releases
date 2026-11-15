source "$(dirname "$0")/helpers.sh"

setup awt-v2
chroot . $java /ImageTest.java
file -i HelloWorld.png | grep -q "image/png; charset=binary"
chroot . $java -Djava.net.useSystemProxies=true -cp / ProxyTest
