source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices dlt-viewer_plugins)"

# The multiarch directory and the dynamic loader's name differ per arch.
loader="$(find "$rootfs" -maxdepth 4 -path "*/lib/*-linux-*/ld*.so.*" -print -quit)"
test -n "$loader"

# dlt-viewer 2.31.0 ships 9 plugins on every arch.
plugins="$(find "$rootfs" -path "*/dlt-viewer/plugins/*.so")"
test "$(echo "$plugins" | wc -l)" -eq 9

# The dynamic loader fails if any shared library a plugin links against is missing.
for plugin in $plugins; do
  chroot "$rootfs" "${loader#"$rootfs"}" --list "${plugin#"$rootfs"}"
done

# dlt-viewer loads every plugin when it starts.
rootfs="$(install-slices dlt-viewer_bins dlt-viewer_plugins)"
write_trace "$rootfs/trace.dlt"
chroot "$rootfs" dlt-viewer -s -t -c trace.txt trace.dlt 2> "$rootfs/stderr"
cat "$rootfs/stderr"
test "$(grep -c "Load plugin" "$rootfs/stderr")" -eq 9
