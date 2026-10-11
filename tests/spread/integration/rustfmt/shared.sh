proc_mounts=()

cleanup() {
    for proc_path in "${proc_mounts[@]}"; do
        umount "$proc_path"
    done
}
trap cleanup EXIT

mount_proc() {
    mkdir -p "$rootfs/proc"
    mount --bind /proc "$rootfs/proc"
    proc_mounts+=("$rootfs/proc")
}
