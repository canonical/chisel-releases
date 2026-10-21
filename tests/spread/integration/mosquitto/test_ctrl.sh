rootfs="$(install-slices mosquitto_ctrl)"
mkdir -p "$rootfs/tmp"

# dynsec is built into mosquitto_ctrl, it does not need the broker plugin
chroot "$rootfs" mosquitto_ctrl --help | grep -Fq "dynsec"
chroot "$rootfs" mosquitto_ctrl dynsec help | grep -Fq "Dynamic Security module"

chroot "$rootfs" mosquitto_ctrl dynsec init /tmp/dynsec.json adminuser adminpass
grep -Eq '"username":[[:space:]]*"adminuser"' "$rootfs/tmp/dynsec.json"
