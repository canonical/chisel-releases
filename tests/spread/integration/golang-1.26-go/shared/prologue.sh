rootfs="$(install-slices golang-1.26-go_${SLICE} golang-1.26-go_minimal)"

find "${rootfs}" -depth \( \
    -name '*_test.go' -o \
    \( -type d -name 'testdata' \) -o \
    \( -type d -path '*/go-1.26/test' \) -o \
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
    \( -type d -path '*/src/net/http/internal/testcert' \) -o \
    \( -type d -path '*/src/crypto/internal/cryptotest' \) -o \
    \( -type d -path '*/src/crypto/internal/fips140/check/checktest' \) -o \
    \( -type d -path '*/src/crypto/internal/fips140test' \) -o \
    \( -type d -path '*/src/crypto/mlkem/mlkemtest' \) -o \
    \( -type d -path '*/src/embed/internal/embedtest' \) -o \
    \( -type d -path '*/src/vendor/golang.org/x/net/nettest' \) \
    \) -exec rm -rf {} +

# we need dev/sys mounted for some of them
mkdir "${rootfs}"/dev
mkdir "${rootfs}/proc"

mount --bind /dev "${rootfs}"/dev
mount --bind /proc "${rootfs}/proc"

mkdir -p "${rootfs}/tmp"

echo -n "${rootfs}"
