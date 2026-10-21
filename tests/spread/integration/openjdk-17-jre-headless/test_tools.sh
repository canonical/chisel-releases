source "$(dirname "$0")/helpers.sh"

setup tools
DNAME="CN=Sample Cert, OU=R&D, O=Company Ltd., L=Dublin 4, S=Dublin, C=IE"
chroot . $(dirname $java)/keytool -genkeypair -keystore foo -storepass barbar -keyalg RSA -dname "$DNAME"
