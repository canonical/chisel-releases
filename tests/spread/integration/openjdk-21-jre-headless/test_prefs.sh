source "$(dirname "$0")/helpers.sh"

setup prefs
chroot . $java /PrefsTest.java put
chroot . $java /PrefsTest.java get
