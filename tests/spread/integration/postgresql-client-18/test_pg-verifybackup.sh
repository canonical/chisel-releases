source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-verifybackup)"

chroot "$rootfs" "/usr/lib/postgresql/18/bin/pg-verifybackup" --version | grep -q "PostgreSQL.* 18"

prepare_postgresql "$rootfs"
start_postgresql

/usr/lib/postgresql/18/bin/createuser testuser
/usr/lib/postgresql/18/bin/createdb -O testuser testdb

/usr/lib/postgresql/18/bin/pg_basebackup -D "$rootfs/tmp/base"
/usr/lib/postgresql/18/bin/pg_basebackup -D "$rootfs/tmp/base-tar" -Ft --compress=server-zstd

chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_verifybackup -n /tmp/base
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_verifybackup -n /tmp/base-tar
# TODO: WAL parsing needs pg_waldump, which ships in postgresql-18. Add it
# here once sliced
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_verifybackup /tmp/base 2>&1 | grep -Fq '"pg_waldump" is needed'

cleanup_postgresql
