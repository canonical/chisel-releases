#!/bin/bash
#spellchecker: ignore rootfs coredump

# What a consumer gets from systemd_config: the default configuration, the
# drop-ins that extend it, and the presets the manager applies.

rootfs="$(install-slices systemd_config)"

for file in /etc/systemd/system.conf /etc/systemd/user.conf /etc/systemd/journald.conf \
  /usr/lib/systemd/system.conf.d/10-coredump-debian.conf \
  /usr/lib/systemd/journald.conf.d/syslog.conf \
  /usr/lib/systemd/system-preset/90-systemd.preset; do
  test -f "$rootfs$file"
done
