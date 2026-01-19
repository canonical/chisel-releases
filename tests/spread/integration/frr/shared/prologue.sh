#!/bin/bash
set -e

SLICES="frr_bins"

if [ "${SPREAD_VARIANT}" = "frr-reload" ]; then
    SLICES="${SLICES} frr_frr-reload"
fi

rootfs="$(install-slices ${SLICES})"

chmod 755 "${rootfs}"

# we need dev/sys mounted for some of them
mkdir "${rootfs}"/dev
mkdir "${rootfs}/proc"

mount --bind /dev "${rootfs}"/dev
mount --bind /proc "${rootfs}/proc"

echo -e "frr:x:999:\nfrrvty:x:998:frr" >> "${rootfs}/etc/group"
echo -e "frr:x:999:999:Frr routing suite,,,:/nonexistent:/usr/sbin/nologin" >> "${rootfs}/etc/passwd"

mkdir -p "${rootfs}/var/lib/frr"
chown 999:999 "${rootfs}/var/lib/frr"

mkdir -p "${rootfs}/tmp"

echo -n "${rootfs}"
