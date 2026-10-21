set -euo pipefail
rootfs="${rootfs:?rootfs not set}"
export CGO_ENABLED=0

cp ./shared/httptest.go "$rootfs/httptest.go"
chroot "$rootfs" /usr/lib/go-1.25/bin/go run /httptest.go |
  grep -Fiq 'httptest works'
chroot "$rootfs" /usr/lib/go-1.25/bin/go vet /httptest.go
