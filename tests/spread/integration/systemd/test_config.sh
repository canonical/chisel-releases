#!/bin/bash
#spellchecker: ignore rootfs osc

# What a consumer gets from systemd_config: the default configuration, with
# the /etc links into it resolving to what the slice ships.

rootfs="$(install-slices systemd_config)"

# the links are absolute, so resolve them inside the rootfs rather than on the host
for link in /etc/profile.d/70-systemd-shell-extra.sh /etc/profile.d/80-systemd-osc-context.sh \
  /etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf; do
  target="$(readlink "$rootfs$link")"
  test -f "$rootfs$target"
done
