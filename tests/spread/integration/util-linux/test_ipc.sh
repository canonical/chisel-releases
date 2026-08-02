#!/bin/bash
#spellchecker: ignore rootfs

rootfs="$(install-slices util-linux_ipc)"

ipcmk_out=$(chroot "$rootfs" ipcmk -M 1)
shm_id=$(echo "$ipcmk_out" | grep -oP '\d+')

chroot "$rootfs" ipcs -m | grep -q "$shm_id"
chroot "$rootfs" ipcrm shm "$shm_id"
chroot "$rootfs" lsipc | grep -q "MSGMNI"
