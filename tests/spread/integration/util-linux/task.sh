summary: Integration tests for util-linux

environment:
  SLICE/blk: "block-devices"
  SLICE/cli: "cli-helpers"
  SLICE/cpu: "cpu"
  SLICE/file: "file-manipulation"
  SLICE/fs: "file-system"
  SLICE/generated: "generated"
  SLICE/ipc: "ipc"
  SLICE/kernel: "kernel"
  SLICE/lock: "lock"
  SLICE/login: "login"
  SLICE/mcookie: "mcookie"
  SLICE/mem: "memory"
  SLICE/namespace: "namespace"
  SLICE/proc: "process"
  SLICE/setarch: "set-arch"
  SLICE/su: "su-support"
  SLICE/timer: "timer"
  SLICE/tty: "tty"

# Binaries involving disk, partition and device operations are only tested with
# the `--help` command as the smoke test.
# Some of the binaries are not possible to be tested with their functionalities
# due to the limitation of the spread test environment.
# Some of the binaries neither changes the status of the system, nor have
# deterministic outputs across different systems. They are tested without
# assertions.

execute: |
  rootfs="$(install-slices util-linux_${SLICE} base-files_base bash_bins)"

  # we need dev/sys mounted for some of them
  mkdir "${rootfs}"/dev
  mkdir "${rootfs}"/proc
  mkdir "${rootfs}"/sys

  mount --bind /dev "${rootfs}"/dev
  mount --bind /proc "${rootfs}"/proc
  mount --bind /sys "${rootfs}"/sys

  case ${SLICE} in
    block-devices)
    ;;
    cli-helpers)

    ;;
    cpu)
      
    ;;
    file-manipulation)

    ;;
    file-system)

    ;;
    generated)
    ;;
    ipc)

    ;;
    kernel)

    ;;
    lock)
    ;;
    login)
    ;;
    mcookie)

    ;;
    namespace)

    ;;
    process)

    ;;
    set-arch)

    ;;
    su-support)
    ;;
    timer)
      chroot "${rootfs}" rtcwake --help
    ;;
    tty)
      chroot "${rootfs}" setterm --help
      chroot "${rootfs}" agetty --help
      chroot "${rootfs}" getty --help
    ;;
  esac

  # cleanup
  umount -l "${rootfs}"/dev
  umount -l "${rootfs}"/proc
  umount -l "${rootfs}"/sys
