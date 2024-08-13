#!/bin/sh
set -ex

mkdir -p /proc/self

for java in `find /usr/lib/jvm -name java`; do
# workaround missing /proc filesystem
    ln -sf ${java} /proc/self/exe
# check that Java machine can be created
    ${java} -version
done
