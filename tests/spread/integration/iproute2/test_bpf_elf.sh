#!/usr/bin/env bash
# spellchecker: ignore rootfs libc

rootfs="$(install-slices gcc_gcc iproute2_headers)"

cp hello_bpf_elf.c "$rootfs/hello_bpf_elf.c"
chroot "$rootfs" gcc -c -o hello_bpf_elf.o hello_bpf_elf.c

# Link with libc and run the binary
rootfs_libc="$(install-slices gcc_gcc libc6-dev_libs)"
cp "$rootfs/hello_bpf_elf.o" "$rootfs_libc/hello_bpf_elf.o"
chroot "$rootfs_libc" gcc -o hello_bpf_elf hello_bpf_elf.o
chroot "$rootfs_libc" ./hello_bpf_elf | grep -q 'Hello, BPF ELF!'
