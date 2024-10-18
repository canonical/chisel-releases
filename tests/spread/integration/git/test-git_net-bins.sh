#!/bin/bash
# Test for network activity.
chroot "${1}" git clone --branch ubuntu-22.04 --depth 1 https://github.com/canonical/chisel-releases
