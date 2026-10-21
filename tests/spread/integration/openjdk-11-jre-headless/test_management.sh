source "$(dirname "$0")/helpers.sh"

setup management
chroot . $java -Dcom.sun.management.jmxremote.port=5000 \
  -Dcom.sun.management.jmxremote.authenticate=false \
  -Dcom.sun.management.jmxremote=true \
  -Dcom.sun.management.jmxremote.ssl=false  -cp . TestJMX
