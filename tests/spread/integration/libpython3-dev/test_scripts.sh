rootfs="$(install-slices libpython3-dev_scripts)"

ln -sf /usr/bin/dash "$rootfs/bin/sh"

case "$(dpkg --print-architecture)" in
  amd64) config=/usr/bin/x86_64-linux-gnu-python3-config ;;
  arm64) config=/usr/bin/aarch64-linux-gnu-python3-config ;;
  armhf) config=/usr/bin/arm-linux-gnueabihf-python3-config ;;
  i386) config=/usr/bin/i386-linux-gnu-python3-config ;;
  ppc64el) config=/usr/bin/powerpc64le-linux-gnu-python3-config ;;
  riscv64) config=/usr/bin/riscv64-linux-gnu-python3-config ;;
  s390x) config=/usr/bin/s390x-linux-gnu-python3-config ;;
  *) echo "Unsupported architecture" >&2; exit 1 ;;
esac
test -x "$rootfs$config"

chroot "$rootfs" "$config" --includes | grep -Fq "/usr/include/python3.14"
