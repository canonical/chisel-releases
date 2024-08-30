#!/bin/bash

# smoketest a couple of netplan commands
netplan --help | grep "Network configuration in YAML"
netplan info | grep "features"

# 'netplan generate' needs udevadm to work
# 'netplan apply' needs udevadm to work
# 'netplan status' does not properly work inside chroot
