source "$(dirname "$0")/helpers.sh"

setup prefs
chroot . $java -cp . PrefsTest put
chroot . $java -cp . PrefsTest get
