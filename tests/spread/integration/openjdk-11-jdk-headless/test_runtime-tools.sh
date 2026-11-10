# no helpers.sh here: its setup compiles with javac, which this slice does not have
rootfs="$(install-slices openjdk-11-jdk-headless_runtime-tools)"
java=/$(find "$rootfs" -name java -type f -printf '%P\n' -quit 2>/dev/null)
home=$(dirname $java)
mkdir -p "$rootfs/proc"
mount --bind /proc "$rootfs/proc"
trap 'umount "$rootfs/proc"' EXIT

chroot "$rootfs" $home/jfr help
chroot "$rootfs" $home/jrunscript -q
