setup() {
  rootfs="$(install-slices "golang-1.27-go_$1" golang-1.27-go_minimal)"

  # the source slice ships go's own tests; drop them as golang-1.27-src
  # documents
  find "$rootfs" -depth \( \
      -name '*_test.go' -o \
      \( -type d -name 'testdata' \) -o \
      \( -type d -path '*/go-1.27/test' \) -o \
      \( -type d -path '*/src/internal/testenv' \) -o \
      \( -type d -path '*/src/internal/testpty' \) -o \
      \( -type d -path '*/src/internal/testhash' \) -o \
      \( -type d -path '*/src/internal/cgrouptest' \) -o \
      \( -type d -path '*/src/internal/obscuretestdata' \) -o \
      \( -type d -path '*/src/internal/coverage/test' \) -o \
      \( -type d -path '*/src/internal/runtime/startlinetest' \) -o \
      \( -type d -path '*/src/internal/runtime/wasitest' \) -o \
      \( -type d -path '*/src/internal/trace/internal/testgen' \) -o \
      \( -type d -path '*/src/internal/trace/testtrace' \) -o \
      \( -type d -path '*/src/net/internal/cgotest' \) -o \
      \( -type d -path '*/src/net/internal/socktest' \) -o \
      \( -type d -path '*/src/os/exec/internal/fdtest' \) -o \
      \( -type d -path '*/src/crypto/internal/cryptotest' \) -o \
      \( -type d -path '*/src/crypto/internal/fips140/check/checktest' \) -o \
      \( -type d -path '*/src/crypto/internal/fips140test' \) -o \
      \( -type d -path '*/src/embed/internal/embedtest' \) -o \
      \( -type d -path '*/src/simd/archsimd/internal/simd_test' \) -o \
      \( -type d -path '*/src/simd/archsimd/internal/test_helpers' \) -o \
      \( -type d -path '*/src/encoding/json/internal/jsontest' \) -o \
      \( -type d -path '*/src/vendor/golang.org/x/net/nettest' \) \
      \) -exec rm -rf {} +

  # some of the tools need /dev and /proc
  mkdir -p "$rootfs/dev" "$rootfs/proc" "$rootfs/tmp"
  mount --bind /dev "$rootfs/dev"
  mount --bind /proc "$rootfs/proc"
  trap 'umount -l "$rootfs/dev" "$rootfs/proc"' EXIT
}
