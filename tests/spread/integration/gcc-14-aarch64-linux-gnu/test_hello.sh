#!/usr/bin/env bash
# spellchecker: ignore rootfs binutils

arch=$(uname -m)
cross=false
if [[ "$arch" == "x86_64" ]]; then
    cross=true
elif [[ "$arch" == "aarch64" ]]; then
    cross=false
else
    echo "Unsupported architecture: $arch"
    exit 1
fi

if $cross; then
    # TODO: We do not have libgcc-14-dev-amd64-cross for cross compilation yet
    rootfs=$(mktemp -d)
else
    rootfs="$(install-slices gcc-14-aarch64-linux-gnu_minimal)"
    ln -s aarch64-linux-gnu-as "$rootfs/usr/bin/as"
    ln -s aarch64-linux-gnu-ld "$rootfs/usr/bin/ld"
    ln -s aarch64-linux-gnu-gcc-14 "$rootfs/usr/bin/gcc"
fi

cat > "${rootfs}/hello.c" << EOF
#include <stdio.h>
int main() {
    printf("Hello from C!\n");
    return 0;
}
EOF

if $cross; then
    # TODO: We do not have libgcc-14-dev-arm64-cross for cross compilation yet
    :
else
    chroot "${rootfs}" gcc /hello.c -o /hello
    chroot "${rootfs}" /hello | grep -q "Hello from C!"
fi
