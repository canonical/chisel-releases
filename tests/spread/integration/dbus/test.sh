#!/bin/bash

# First thing is to create a system uuid
mkdir -p /var/lib/dbus/
dbus-uuidgen > /var/lib/dbus/machine-id

# Start the daemon
mkdir -p /run/dbus
dbus-daemon --system

# Test by sending, but allow a moment for the service to get up
sleep 1
dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.ListNames
