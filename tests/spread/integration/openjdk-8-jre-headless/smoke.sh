#!/bin/sh

set -ex

for java in `find /usr/lib/jvm -name java`; do
# workaround missing /proc filesystem
    mkdir -p ${rootfs}/proc/self
    ln -sf ${java} /proc/self/exe
# check that Java machine can be created
    ${java} -version
done
