# Exercise the FIPS data with the Go toolchain that consumes it.
rootfs="$(install-slices golang-1.27-go_core)"

mkdir -p "$rootfs/dev" "$rootfs/proc"
cleanup() {
  umount "$rootfs/proc"
  umount "$rootfs/dev"
}
mount --bind /dev "$rootfs/dev"
trap 'umount "$rootfs/dev"' EXIT
mount --bind /proc "$rootfs/proc"
trap cleanup EXIT

cat > "$rootfs/fips.go" <<'EOF'
package main

import (
    "crypto/fips140"
    "crypto/sha256"
    "fmt"
    "runtime/debug"
)

func main() {
    if !fips140.Enabled() {
        panic("FIPS mode is disabled")
    }
    fmt.Printf("%x\n", sha256.Sum256([]byte("abc")))
    info, ok := debug.ReadBuildInfo()
    if !ok {
        panic("missing build information")
    }
    for _, setting := range info.Settings {
        if setting.Key == "GOFIPS140" {
            fmt.Println(setting.Value)
            return
        }
    }
    panic("missing GOFIPS140 build setting")
}
EOF

# Compare the Go digest with an independent implementation on the test host.
read -r expected_digest _ < <(printf '%s' abc | sha256sum)
# Check the resolved snapshot, including its suffix, without pinning a version.
expected_snapshot="$(cat "$rootfs/usr/share/go-1.27/lib/fips140/certified.txt")"
expected="$(printf '%s\n%s' "$expected_digest" "$expected_snapshot")"
actual="$(GOFIPS140=certified CGO_ENABLED=0 GODEBUG='' \
  chroot "$rootfs" /usr/lib/go-1.27/bin/go run /fips.go)"
test "$actual" = "$expected"
