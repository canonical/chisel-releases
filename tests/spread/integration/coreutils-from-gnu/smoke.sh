#!/bin/bash
#
# This script smoke tests each slice containing bins and their respective
# binaries. For most of the binaries, this script simply checks if the --help
# option works or not. The only exceptions are "false", "printf", "pwd" and "[".

set -eu

PKG_NAME="coreutils-from-gnu"
SDF="${PROJECT_PATH}/slices/${PKG_NAME}.yaml"
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
    slice="${PKG_NAME}_${s}"
    echo "Testing $slice ..."
    install_slices "$slice"

    files=$(s="$s" yq ".slices.[env(s)].contents | keys | .[]" "${SDF}")
    for file in ${files[@]}; do
        cmd="$(basename "$file")"
        run_command "$cmd"
        all_cmds+=($cmd)
    done
done

echo "Testing ${PKG_NAME}_bins ..."
install_slices "${PKG_NAME}_bins"
for cmd in ${all_cmds[@]}; do
    run_command "$cmd"
done
