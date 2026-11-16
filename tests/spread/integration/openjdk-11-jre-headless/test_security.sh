source "$(dirname "$0")/helpers.sh"

setup security
chroot . $java -cp . ReadCertificate

# NSS seeds itself from the random device
mkdir -p dev
touch dev/urandom
mount --bind /dev/urandom dev/urandom
trap 'umount dev/urandom' EXIT
out="$(chroot . $java -cp . NssProvider /etc/java-11-openjdk/security/nss.cfg)"
test "$out" = "provider: SunPKCS11-NSS"
