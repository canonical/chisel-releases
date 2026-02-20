#!/usr/bin/env bash
#spellchecker: ignore rootfs libmodule scandeps libperl

apt update
apt install -y libmodule-scandeps-perl python3-yaml
trap "apt remove -y libmodule-scandeps-perl python3-yaml &> /dev/null || true" EXIT

# prepare the imports for each slice which has *.pm files
mkdir cases
python3 prepare_test_imports.py "$PROJECT_PATH" cases

for slice in $(find cases -type f -printf "%f\n"); do
    slice_name=$(echo "$slice" | cut -d. -f1)
    echo "Testing slice: $slice_name"
    rootfs=$(install-slices "libperl5.40_$slice_name" base-files_base perl-base_bins)
    cp "cases/$slice" "$rootfs"
    chroot "$rootfs" /usr/bin/perl "$slice"
done

  
  
