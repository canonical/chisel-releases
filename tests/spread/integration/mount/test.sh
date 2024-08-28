#!/bin/bash

# Run a smoke test for mount and umount to verify that
# they are doing what we expect by testing on /proc
mkdir /test-bin
mount --bind /bin /test-bin
count=$(ls /test-bin | wc -l)
umount /test-bin

if [ $count -eq 0 ]
then
    echo "no files in /test-bin, did mount not work?"
    exit 1
fi
