source "$(dirname "$0")/helpers.sh"

setup security
chroot . $java /ReadCertificate.java
