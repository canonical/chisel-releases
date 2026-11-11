source "$(dirname "$0")/helpers.sh"

setup awt-v2
chroot . $java /ImageTest.java
file -i HelloWorld.png | grep -q "image/png; charset=binary"
chroot . $java -Djava.net.useSystemProxies=true -cp / ProxyTest
# the trimmed font stack leaves out gio, brotli's encoder and libexpatw
test -z "$(find . -name 'libgio-2.0.so*' -o -name 'libbrotlienc.so*' -o -name 'libexpatw.so*')"
