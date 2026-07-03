# TODO: remove the --arch and the ${arch} logic once
# canonical/chisel #256 is merged.
arch=$(uname -m)

case "${arch}" in
  aarch64)   chisel_arch="arm64";    arch_triplet="aarch64-linux-gnu" ;;
  x86_64)    chisel_arch="amd64";    arch_triplet="x86_64-linux-gnu" ;;
  ppc64le)   chisel_arch="ppc64el";  arch_triplet="powerpc64le-linux-gnu" ;;
  s390x)     chisel_arch="s390x";    arch_triplet="s390x-linux-gnu" ;;
  *)         echo "Unsupported architecture: ${arch}"; exit 1 ;;
esac

rootfs="$(install-slices --arch "${chisel_arch}" gcc-15_gcc-15 libc6-dev_libs)"

cp ../gcc-15-${arch_triplet}/testfiles/hello.c "${rootfs}/hello.c"

chroot "${rootfs}" gcc-15 -o hello hello.c
chroot "${rootfs}" ./hello | grep "Hello from C!"
