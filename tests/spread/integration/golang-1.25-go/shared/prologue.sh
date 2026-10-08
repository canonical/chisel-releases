rootfs="$(install-slices "golang-1.25-go_${SLICE}" golang-1.25-go_minimal)"

# Prune Go's own tests using the command documented in golang-1.25-src.yaml.
(
  cd "$rootfs" || exit
  find . -depth \( \
    \( -path '*test*' \
       ! -path '*src/testing*' \
       ! -path '*src/internal/test*' \
       ! -path '*src/internal/synctest' \
       ! -path '*synctest.go' \
       ! -path '*synctest_o*' \
       ! -path '*src/net/http/httptest*' \
       ! -path '*src/net/http/internal/testcert*' \) -o \
    \( -path '*/testing/*' -name '*_test.go' \) \
    \) -exec rm -rf {} +
)

# we need dev/sys mounted for some of them
mkdir "${rootfs}"/dev
mkdir "${rootfs}/proc"

mount --bind /dev "${rootfs}"/dev
mount --bind /proc "${rootfs}/proc"

mkdir -p "${rootfs}/tmp"

echo -n "${rootfs}"
