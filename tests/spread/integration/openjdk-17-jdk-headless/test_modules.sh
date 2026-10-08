source "$(dirname "$0")/helpers.sh"

setup modules
cd $rootfs
output=$(basename $(mktemp -u))
chroot . $home/jlink --add-modules java.base --output $output
rm -rf $rootfs/$output
chroot . $home/jmod list $home/../jmods/java.rmi.jmod
