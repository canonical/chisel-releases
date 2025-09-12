#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs libexec ifdef ifndef

arch=$(uname -m)-linux-gnu
rootfs="$(install-slices \
    base-files_bin \
    cpp-14-"${arch//_/-}"_cc1 \
)"
ln -s "/usr/libexec/gcc/$arch/14/cc1" "${rootfs}/usr/bin/cc1"

# make apple.cpp
cat > "${rootfs}/apple.cpp"<<EOF
#include <fruit/banana.h>

int main() {
    #ifdef BANANA_MESSAGE
        return 0; // BANANA_MESSAGE is defined // BANANA_MESSAGE is not defined
    #else
        return 1; // BANANA_MESSAGE is not defined
    #endif
}
EOF

mkdir -p "${rootfs}/usr/include/fruit"
cat > "${rootfs}/usr/include/fruit/banana.h"<<EOF
#ifndef FRUIT_BANANA_H
#define FRUIT_BANANA_H

#define BANANA_MESSAGE "Hello from banana!"

#endif // FRUIT_BANANA_H
EOF

mkdir -p "${rootfs}/usr/include/fruit"
chroot "${rootfs}" cc1 -E apple.cpp > "${rootfs}/apple.i" 2>/dev/null
cat "${rootfs}/apple.i" | grep -q 'return 0;'

# now remove banana.h and check that BANANA_MESSAGE is not defined
echo "" > "${rootfs}/usr/include/fruit/banana.h"
chroot "${rootfs}" cc1 -E apple.cpp > "${rootfs}/apple.i" 2>/dev/null
cat "${rootfs}/apple.i" | grep -q 'return 1;'
