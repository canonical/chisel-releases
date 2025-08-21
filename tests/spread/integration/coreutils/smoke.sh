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

limit_concurrent_jobs() {
    local max_jobs=$1
    while [ "$(jobs -r | wc -l)" -ge "$max_jobs" ]; do
        sleep 1
    done
}

all_cmds=()

slices=(
  output-of-entire-files
  formatting-file-contents
  output-of-parts-of-files
  summarizing-files
  operating-on-sorted-files
  operating-on-fields
  operating-on-characters
  directory-listing
  basic-operations
  special-file-types
  changing-file-attributes
  file-space-usage
  printing-text
  conditions
  redirection
  file-name-manipulation
  working-context
  user-information
  system-context
  selinux-context
  modified-command-invocation
  delaying
  numeric-operations
)

for s in ${slices[@]}; do
    slice="coreutils_$s"
    echo "Testing $slice ..."
    install_slices "$slice"

    files=$(s="$s" yq ".slices.[env(s)].contents | keys | .[]" "${SDF}")
    for file in ${files[@]}; do
        cmd="$(basename "$file")"
        run_command "$cmd" &
        all_cmds+=($cmd)
    done
    wait
done

echo "Testing coreutils_bins ..."
install_slices "coreutils_bins"
for cmd in ${all_cmds[@]}; do
    limit_concurrent_jobs 4
    run_command "$cmd" &
done
wait
