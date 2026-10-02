#!/bin/bash
#spellchecker: ignore rootfs rslave tmpfiles

# What a consumer gets from systemd_ask-password: a program that asks for a
# password without a terminal of its own, and the agent that answers it on one.

rootfs="$(install-slices systemd_ask-password)"
for bin in /usr/bin/systemd-ask-password /usr/bin/systemd-tty-ask-password-agent; do
  chroot "$rootfs" "$bin" --version | grep -Eq '^systemd [0-9]+ '
done

# tmpfiles makes the directory the queries go through at boot
mkdir -p "$rootfs/proc" "$rootfs/dev" "$rootfs/run/systemd/ask-password"
mount --bind /proc "$rootfs/proc"
mount --rbind /dev "$rootfs/dev"
mount --make-rslave "$rootfs/dev"
trap 'kill "${asker:-}" 2>/dev/null || true; umount -R "$rootfs/dev"; umount "$rootfs/proc"' EXIT

# with no terminal, the question waits for an agent
chroot "$rootfs" systemd-ask-password --no-tty --timeout=60 "chisel test:" > "$rootfs/answer" &
asker=$!
for _ in $(seq 1 20); do
  chroot "$rootfs" systemd-tty-ask-password-agent --list | grep -Fq "chisel test:" && break
  sleep 0.5
done
chroot "$rootfs" systemd-tty-ask-password-agent --list | grep -Fq "chisel test:"

# the agent asks on its own terminal and hands the answer back
{ sleep 1; printf 'hunter2\n'; sleep 1; } \
  | timeout 30 script -qec "chroot $rootfs systemd-tty-ask-password-agent --query" /dev/null >/dev/null
wait "$asker"
grep -Fxq "hunter2" "$rootfs/answer"
