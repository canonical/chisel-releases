#!/usr/bin/env bash
# spellchecker: ignore rootfs libgcc libexec libc multiarch

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
    gcc_dir="gcc-cross"
    sysroot="/"
else
    gcc_dir="gcc"
    sysroot=""
fi

rootfs="$(install-slices gcc-aarch64-linux-gnu_gcc)"
    ln -s "aarch64-linux-gnu-gcc" "${rootfs}/usr/bin/gcc"

test "$(chroot "${rootfs}" gcc -print-search-dirs | head -n 1)" = "install: /usr/lib/$gcc_dir/aarch64-linux-gnu/15/"
chroot "${rootfs}" gcc -print-search-dirs | head -n 2 | tail -n 1 | grep -q "/usr/libexec/$gcc_dir/aarch64-linux-gnu/15/"

test "$(chroot "${rootfs}" gcc -print-libgcc-file-name)" = "libgcc.a"
chroot "${rootfs}" gcc -print-file-name=libc.so.6 | grep -q "libc.so.6"

# create a fake program called 'foo' in libexec dir to test -print-prog-name
touch "${rootfs}/usr/libexec/$gcc_dir/aarch64-linux-gnu/15/foo"
chmod +x "${rootfs}/usr/libexec/$gcc_dir/aarch64-linux-gnu/15/foo"

chroot "${rootfs}" gcc -print-prog-name=foo
test "$(chroot "${rootfs}" gcc -print-prog-name=foo)" = "/usr/libexec/$gcc_dir/aarch64-linux-gnu/15/foo"

# we're not configured for multiple architectures
test "$(chroot "${rootfs}" gcc -print-multiarch)" = "aarch64-linux-gnu"
test "$(chroot "${rootfs}" gcc -print-multi-directory)" = "."
chroot "${rootfs}" gcc -print-multi-lib # the output may vary. just run it
test "$(chroot "${rootfs}" gcc -print-multi-os-directory)" = "../lib"

test "$(chroot "${rootfs}" gcc -print-sysroot)" = "$sysroot"
(chroot "${rootfs}" gcc -print-sysroot-headers-suffix 2>&1 || true) | grep -q "not configured with sysroot"
