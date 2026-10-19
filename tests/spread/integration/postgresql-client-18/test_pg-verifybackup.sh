source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-verifybackup)"

test -e "$rootfs/bin/sh"

bins="pg_verifybackup"
for bin in $bins; do
  test -x "$rootfs/usr/lib/postgresql/18/bin/${bin}"
  chroot "$rootfs" "/usr/lib/postgresql/18/bin/${bin}" --version | grep -q "PostgreSQL.* 18"
done

prepare_postgresql "$rootfs"
start_postgresql

chroot "$rootfs" /usr/lib/postgresql/18/bin/createuser testuser
chroot "$rootfs" /usr/lib/postgresql/18/bin/createdb -O testuser testdb

chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_basebackup -D /tmp/base
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_verifybackup -n /tmp/base

cleanup_postgresql "$rootfs"
