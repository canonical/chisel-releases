rootfs="$(install-slices libegl-mesa0_libs libegl1_libs libpython3-stdlib_all-os python3_core)"
cp verify.py "$rootfs"

# Mesa's surfaceless platform needs no display server and falls back to software rendering.
EGL_PLATFORM=surfaceless chroot "$rootfs" python3 verify.py
