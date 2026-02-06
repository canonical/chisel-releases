#!/bin/bash

# create python3 symlink
ln -s /usr/bin/python3.12 /usr/bin/python3 

# smoketest a couple of netplan commands
netplan --help | grep "Network configuration in YAML"
netplan info | grep "features"

# 'netplan generate' needs udevadm to work
# 'netplan apply' needs udevadm to work
# 'netplan status' does not properly work inside chroot
