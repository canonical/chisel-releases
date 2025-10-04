#!/usr/bin/env bash

if [[ "$1" != "--spread" ]]; then
    FILE_DIR=$(realpath "$(dirname "$0")")
    source "$FILE_DIR"/setup.sh
fi

## TESTS 
# spellchecker: ignore rootfs coreutils

# Run single-binary slices tests
# Forward port from 24.04

# test env
rootfs="$(install-slices gnu-coreutils_env)"
chroot "$rootfs" gnuenv --version

# test expr
rootfs="$(install-slices gnu-coreutils_expr)"
chroot "$rootfs" gnuexpr --version

# test mkdir
rootfs="$(install-slices gnu-coreutils_mkdir)"
chroot "$rootfs" gnumkdir test_dir
test -d "$rootfs/test_dir"

# test echo
rootfs="$(install-slices gnu-coreutils_echo)"
chroot "$rootfs" gnuecho "Hello, World!"

# test ln
rootfs="$(install-slices gnu-coreutils_ln-utility)"
touch "$rootfs/test_file"
chroot "$rootfs" gnuln -s test_file test_link
test -L "$rootfs/test_link"

# test rm
rootfs="$(install-slices gnu-coreutils_rm-utility)"
touch "$rootfs/test_file"
chroot "$rootfs" gnurm test_file
test ! -e "$rootfs/test_file"

# test readlink
rootfs="$(install-slices gnu-coreutils_readlink)"
touch "$rootfs/test_file"
ln -s test_file "$rootfs/test_link"
chroot "$rootfs" gnureadlink test_link | grep "test_file"

# test sort
rootfs="$(install-slices gnu-coreutils_sort)"
echo -e "banana\napple\ncherry" > "$rootfs/test_file"
chroot "$rootfs" gnusort test_file > "$rootfs"/sorted_output
# NOTE: sorted output has a trailing newline. replaced by hyphen to show better
test "$(cat "$rootfs"/sorted_output | tr '\n' '-')" = "apple-banana-cherry-"

# test dirname
rootfs="$(install-slices gnu-coreutils_dirname)"
mkdir -p "$rootfs/foo/bar"
touch "$rootfs/foo/bar/baz.txt"
test "$(chroot "$rootfs" gnudirname /foo/bar/baz.txt)" = "/foo/bar"
test "$(chroot "$rootfs" gnudirname /foo/bar/)" = "/foo"

# test touch
rootfs="$(install-slices gnu-coreutils_touch)"
chroot "$rootfs" gnutouch test_file
test -e "$rootfs/test_file"

# test printf
rootfs="$(install-slices gnu-coreutils_printf)"
test "$(chroot "$rootfs" gnuprintf "hello\n" )" = "hello"
test "$(chroot "$rootfs" gnuprintf "hello-%s\n" "world")" = "hello-world"
test "$(chroot "$rootfs" gnuprintf "number: %d\n" 42)" = "number: 42"
test "$(chroot "$rootfs" gnuprintf "float: %.2f\n" 3.14159)" = "float: 3.14"

# test cat
rootfs="$(install-slices gnu-coreutils_cat)"
echo "Hello, World!" > "$rootfs/test_file"
test "$(chroot "$rootfs" gnucat test_file)" = "Hello, World!"

# test uname
rootfs="$(install-slices gnu-coreutils_uname)"
test "$(chroot "$rootfs" gnuuname -s)" = "Linux"
test "$(chroot "$rootfs" gnuuname -m)" = "$(uname -m)"
test "$(chroot "$rootfs" gnuuname -r)" != ""

# test chown
# we cannot test changing ownership in chroot
rootfs="$(install-slices gnu-coreutils_chown)"
touch "$rootfs/test_file"
output=$(chroot "$rootfs" gnuchown invalid:user test_file 2>&1 || true)
echo "$output" | grep "invalid user"

# test mv
rootfs="$(install-slices gnu-coreutils_mv-utility)"
echo "Test content" > "$rootfs/source_file"
chroot "$rootfs" gnumv source_file dest_file
test ! -e "$rootfs/source_file"
test -e "$rootfs/dest_file"
test "$(cat "$rootfs/dest_file")" = "Test content"
