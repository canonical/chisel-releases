#!/bin/bash

# smoketest ip commands
ip --help | grep "Usage:"

# test some basic commands and against loopback that
# we can kinda expect is there
ip link | grep "LOOPBACK,UP"
ip addr | grep "inet 127.0.0.1"
ip route | grep -E "default via [0-9\.]+"

# iproute carries many binaries
# so maybe extend as needed
