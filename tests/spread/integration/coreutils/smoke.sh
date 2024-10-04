#!/bin/bash
#
# This script smoke tests each slice containing bins and their respective
# binaries. For most of the binaries, this script simply checks if the --help
# option works or not. The only exceptions are "false", "printf", "pwd" and "[".

set -eu

SDF="${PROJECT_PATH}/slices/coreutils.yaml"
ROOTFS="$(mktemp -d)"

install_slices() {
    ROOTFS=$(install-slices $@)
}

run_command() {
    local cmd="$1"
    echo -e "\tChecking $cmd ..."
    case "$cmd" in
        "false" )   ! chroot "${ROOTFS}" $cmd                  ;;
        "printf")   chroot "${ROOTFS}" $cmd foo > /dev/null    ;;
        "pwd"   )   chroot "${ROOTFS}" $cmd > /dev/null        ;;
        "["     )                                              ;;
        *       )   chroot "${ROOTFS}" $cmd --help > /dev/null ;;
    esac
}

all_cmds=()
slices=$(yq '.slices | keys | .[]' "${SDF}")
for s in ${slices[@]}; do
    if [[ "$s" == "libs" || "$s" == "bins" || "$s" == "copyright" ]]; then
        continue
    fi

    slice="coreutils_$s"
    echo "Testing $slice ..."
    install_slices "$slice"

    files=$(s="$s" yq ".slices.[env(s)].contents | keys | .[]" "${SDF}")
    for file in ${files[@]}; do
        cmd="$(basename "$file")"
        run_command "$cmd"
        all_cmds+=($cmd)
    done
done

echo "Testing coreutils_bins ..."
install_slices "coreutils_bins"
for cmd in ${all_cmds[@]}; do
    run_command "$cmd"
done
