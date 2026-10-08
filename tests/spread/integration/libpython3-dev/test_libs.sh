rootfs="$(install-slices libpython3-dev_libs)"

pc="$(find "$rootfs/usr/lib" -path "*/pkgconfig/python3.pc" -print -quit)"
embed_pc="$(find "$rootfs/usr/lib" -path "*/pkgconfig/python3-embed.pc" -print -quit)"
test -n "$pc"
test -n "$embed_pc"
test "$(readlink "$pc")" = "python-3.14.pc"
test "$(readlink "$embed_pc")" = "python-3.14-embed.pc"
