#!/bin/bash

# Run some smoke-tests by invoking a couple of commands
# from systemd to verify it's doing exactly what we expect
# it to
systemctl disable getty@tty1.service
! test -f "/etc/systemd/system/getty.target.wants/getty@tty1.service"

systemctl enable getty@tty1.service
test -f "/etc/systemd/system/getty.target.wants/getty@tty1.service"

# run preset-all and test for one of the expected symlinks
systemctl preset-all
test -f "/etc/systemd/system/ctrl-alt-del.target"

# Run some auxiliary commands to ensure they don't fail
systemd --help
journalctl --update-catalog
