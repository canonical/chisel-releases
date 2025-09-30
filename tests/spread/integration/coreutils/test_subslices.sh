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
rootfs="$(install-slices coreutils_env)"
chroot "$rootfs" env --version

# test expr
rootfs="$(install-slices coreutils_expr)"
chroot "$rootfs" expr --version

# test mkdir
rootfs="$(install-slices coreutils_mkdir)"
chroot "$rootfs" mkdir test_dir
test -d "$rootfs/test_dir"

# test echo
rootfs="$(install-slices coreutils_echo)"
chroot "$rootfs" echo "Hello, World!"

# test ln
rootfs="$(install-slices coreutils_ln-utility)"
touch "$rootfs/test_file"
chroot "$rootfs" ln -s test_file test_link
test -L "$rootfs/test_link"

# test rm
rootfs="$(install-slices coreutils_rm-utility)"
touch "$rootfs/test_file"
chroot "$rootfs" rm test_file
test ! -e "$rootfs/test_file"

# test readlink
rootfs="$(install-slices coreutils_readlink)"
touch "$rootfs/test_file"
ln -s test_file "$rootfs/test_link"
chroot "$rootfs" readlink test_link | grep "test_file"

# test sort
rootfs="$(install-slices coreutils_sort)"
echo -e "banana\napple\ncherry" > "$rootfs/test_file"
chroot "$rootfs" sort test_file > "$rootfs"/sorted_output
# NOTE: sorted output has a trailing newline. replaced by hyphen to show better
test "$(cat "$rootfs"/sorted_output | tr '\n' '-')" = "apple-banana-cherry-"

# test dirname
rootfs="$(install-slices coreutils_dirname)"
mkdir -p "$rootfs/foo/bar"
touch "$rootfs/foo/bar/baz.txt"
test "$(chroot "$rootfs" dirname /foo/bar/baz.txt)" = "/foo/bar"
test "$(chroot "$rootfs" dirname /foo/bar/)" = "/foo"

# test touch
rootfs="$(install-slices coreutils_touch)"
chroot "$rootfs" touch test_file
test -e "$rootfs/test_file"

# test printf
rootfs="$(install-slices coreutils_printf)"
test "$(chroot "$rootfs" printf "hello\n" )" = "hello"
test "$(chroot "$rootfs" printf "hello-%s\n" "world")" = "hello-world"
test "$(chroot "$rootfs" printf "number: %d\n" 42)" = "number: 42"
test "$(chroot "$rootfs" printf "float: %.2f\n" 3.14159)" = "float: 3.14"

# test cat
rootfs="$(install-slices coreutils_cat)"
echo "Hello, World!" > "$rootfs/test_file"
test "$(chroot "$rootfs" cat test_file)" = "Hello, World!"

# test uname
rootfs="$(install-slices coreutils_uname)"
test "$(chroot "$rootfs" uname -s)" = "Linux"
test "$(chroot "$rootfs" uname -m)" = "$(uname -m)"
test "$(chroot "$rootfs" uname -r)" != ""

# test chown
# we cannot test changing ownership in chroot
rootfs="$(install-slices coreutils_chown)"
touch "$rootfs/test_file"
output=$(chroot "$rootfs" chown invalid:user test_file 2>&1 || true)
echo "$output" | grep "invalid user"

# test mv
rootfs="$(install-slices coreutils_mv-utility)"
echo "Test content" > "$rootfs/source_file"
chroot "$rootfs" mv source_file dest_file
test ! -e "$rootfs/source_file"
test -e "$rootfs/dest_file"
test "$(cat "$rootfs/dest_file")" = "Test content"
