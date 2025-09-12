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

# make main.c
cat > "${rootfs}/main.c"<<EOF
#include <everything/answer.h>

int main() {
    #ifdef ANSWER
        return 0;
    #else
        return 1;
    #endif
}
EOF

mkdir -p "${rootfs}/usr/include/everything"
cat > "${rootfs}/usr/include/everything/answer.h"<<EOF
#ifndef MY_MATH_H
#define MY_MATH_H
#define ANSWER 42
#endif // MY_MATH_H
EOF

mkdir -p "${rootfs}/usr/include/everything"
chroot "${rootfs}" cc1 -E main.c > "${rootfs}/main.i" 2>/dev/null
cat "${rootfs}/main.i" | grep -q 'return 0;'

# now remove answer.h and check that ANSWER is not defined
echo "" > "${rootfs}/usr/include/everything/answer.h"
chroot "${rootfs}" cc1 -E main.c > "${rootfs}/main.i" 2>/dev/null
cat "${rootfs}/main.i" | grep -q 'return 1;'
