#!/bin/bash
#spellchecker: ignore rootfs

# What a consumer gets from rabbitmq-server_autocomplete: completion for the
# tools in a shell that has them.

rootfs="$(install-slices rabbitmq-server_autocomplete bash_bins)"

chroot "$rootfs" bash -c '. /usr/lib/rabbitmq/autocomplete/bash_autocomplete.sh && complete -p rabbitmqctl rabbitmq-plugins rabbitmq-diagnostics'
