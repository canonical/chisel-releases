rootfs="$(install-slices mosquitto_bins)"
mkdir -p "$rootfs/tmp"

chroot "$rootfs" mosquitto_ctrl --help | grep -Fq "dynsec"
chroot "$rootfs" mosquitto_ctrl dynsec help | grep -Fq "Dynamic Security module"

chroot "$rootfs" mosquitto_ctrl dynsec init /tmp/dynsec.json adminuser adminpass
grep -Eq '"username":[[:space:]]*"adminuser"' "$rootfs/tmp/dynsec.json"
