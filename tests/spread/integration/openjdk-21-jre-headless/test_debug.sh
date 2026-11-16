source "$(dirname "$0")/helpers.sh"

setup debug
chroot . $java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005 /Main.java
