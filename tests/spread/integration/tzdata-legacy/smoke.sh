#!/bin/bash
#
# This script smoke tests each tzdata-legacy slice and it simply checks if all
# symbolic link targets are present.

set -eu

PKG="tzdata-legacy"
SDF="${PROJECT_PATH}/slices/${PKG}.yaml"

slices=$(yq '.slices | keys | .[]' "${SDF}")
for s in ${slices[@]}; do
    slice="${PKG}_$s"
    echo "Testing $slice ..."
    rootfs="$(install-slices "$slice")"

    find "$rootfs" -type l -printf "%P\0" | while IFS= read -r -d $'\0' file; do
        if [[ ! -e "$rootfs/$file" ]]; then
            target="$(readlink "$rootfs/$file")"
            echo "symlink /$file -> $target broken"
            exit 1
        fi
    done
done
