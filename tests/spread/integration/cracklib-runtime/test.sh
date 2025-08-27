#!/bin/sh

# simple test
echo "password" | /usr/sbin/cracklib-check | grep "you are not registered"

# format list of words for packer and invoke packer
/usr/sbin/cracklib-format ./lower.tar.gz | /usr/sbin/cracklib-packer ./test.db

if ! [ -e ./test.db.hwm ]; then
    echo "expected ./test.db.hwm to exist"
    exit -1
fi

if ! [ -e ./test.db.pwd ]; then
    echo "expected ./test.db.hwm to exist"
    exit -1
fi

if ! [ -e ./test.db.pwi ]; then
    echo "expected ./test.db.pwi to exist"
    exit -1
fi

# unpack again
/usr/sbin/cracklib-unpacker ./test.db > ./words.txt
