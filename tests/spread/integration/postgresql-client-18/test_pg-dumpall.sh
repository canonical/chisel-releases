source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-dumpall)"

chroot "$rootfs" "/usr/lib/postgresql/18/bin/pg_dumpall" --version | grep -q "PostgreSQL.* 18"

prepare_postgresql "$rootfs"
start_postgresql

/usr/lib/postgresql/18/bin/createuser testuser
/usr/lib/postgresql/18/bin/createdb -O testuser testdb

chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_dumpall > /tmp/all.sql
grep -Fq "CREATE ROLE testuser" /tmp/all.sql
grep -Fq "CREATE DATABASE testdb" /tmp/all.sql

cleanup_postgresql
