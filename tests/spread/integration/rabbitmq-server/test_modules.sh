#!/bin/bash
#spellchecker: ignore rootfs

# What rabbitmq-server_modules has to hold on its own: every erlang application
# a shipped plugin depends on, so that enabling any of them can load it.

# shellcheck source=tests/spread/integration/rabbitmq-server/helpers.sh
. ./helpers.sh

rootfs="$(install-slices rabbitmq-server_modules)"
assert_app_closure "$rootfs"
