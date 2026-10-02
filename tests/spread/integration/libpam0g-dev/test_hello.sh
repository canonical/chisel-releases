#!/bin/bash
#spellchecker: ignore rootfs libc libpam lpam

rootfs="$(install-slices gcc_gcc libc6-dev_libs libpam0g-dev_headers)"

cp hello-pam.c "$rootfs/hello-pam.c"
chroot "$rootfs" gcc -c -o hello-pam.o hello-pam.c

# can't link since we don't have the actual library
chroot "$rootfs" gcc -o hello-pam hello-pam.o -lpam 2>&1 | grep -q "cannot find -lpam"

# so let's link it it a different rootfs with the library slices
rootfs_libs=$(install-slices gcc_gcc libc6-dev_libs libpam0g-dev_libs)
cp "$rootfs/hello-pam.o" "$rootfs_libs/hello-pam.o"
chroot "$rootfs_libs" gcc -o hello-pam hello-pam.o -lpam

# we can't run here since we don't have all the other PAM stuff
chroot "$rootfs_libs" ./hello-pam 2>&1 | grep -q "Critical error"

# create a rootfs in which we can run the hello-pam successfully
rootfs_runtime=$(install-slices libpam-modules_libs libpam-runtime_config)
cat > "$rootfs_runtime/etc/pam.d/hello-pam" <<EOF
auth    required    pam_permit.so
account required    pam_permit.so
session required    pam_permit.so
EOF
cp "$rootfs_libs/hello-pam" "$rootfs_runtime/hello-pam"
chroot "$rootfs_runtime" ./hello-pam | grep -q "PAM says: Hello, world!"
