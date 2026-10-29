source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_bins)"


bins="clusterdb createdb createuser dropdb dropuser pg_amcheck
  pg_basebackup pg_combinebackup pg_config pg_dump
  pg_isready pg_receivewal pg_recvlogical pg_restore
  psql reindexdb vacuumdb"
for bin in $bins; do
  chroot "$rootfs" "/usr/lib/postgresql/18/bin/${bin}" --version | grep -q "PostgreSQL.* 18"
done

prepare_postgresql "$rootfs"
start_postgresql

chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_isready
chroot "$rootfs" /usr/lib/postgresql/18/bin/psql -Atc "select 1" | grep -qx 1

# user/db management
chroot "$rootfs" /usr/lib/postgresql/18/bin/createuser testuser
chroot "$rootfs" /usr/lib/postgresql/18/bin/createdb -O testuser testdb
chroot "$rootfs" /usr/lib/postgresql/18/bin/psql -d testdb -c "create table t(i int primary key); insert into t values (42);"
chroot "$rootfs" /usr/lib/postgresql/18/bin/psql -d testdb -c "create extension amcheck"

# maintenance tools
chroot "$rootfs" /usr/lib/postgresql/18/bin/vacuumdb testdb
chroot "$rootfs" /usr/lib/postgresql/18/bin/reindexdb testdb
chroot "$rootfs" /usr/lib/postgresql/18/bin/clusterdb testdb
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_amcheck testdb

# pg_config
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_config --bindir | grep -qx "/usr/lib/postgresql/18/bin"

# pg_dump (plain) + psql restore
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_dump testdb > /tmp/testdb.sql
grep -Fq 42 /tmp/testdb.sql
chroot "$rootfs" /usr/lib/postgresql/18/bin/dropdb testdb
chroot "$rootfs" /usr/lib/postgresql/18/bin/createdb testdb
chroot "$rootfs" /usr/lib/postgresql/18/bin/psql -d testdb < /tmp/testdb.sql
chroot "$rootfs" /usr/lib/postgresql/18/bin/psql -d testdb -Atc "select i from t" | grep -qx 42

# pg_dump (custom) + pg_restore
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_dump -Fc testdb > /tmp/testdb.dump
chroot "$rootfs" /usr/lib/postgresql/18/bin/dropdb testdb
chroot "$rootfs" /usr/lib/postgresql/18/bin/createdb testdb
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_restore -d testdb < /tmp/testdb.dump
chroot "$rootfs" /usr/lib/postgresql/18/bin/psql -d testdb -Atc "select i from t" | grep -qx 42

# base backup, verify, incremental backup, combine
# (paths below are inside the chroot)
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_basebackup -D /tmp/base
chroot "$rootfs" /usr/lib/postgresql/18/bin/psql -d testdb -c "insert into t values (43)"
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_basebackup -D /tmp/incr -i /tmp/base/backup_manifest
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_combinebackup /tmp/base /tmp/incr -o /tmp/combined
test -f "$rootfs/tmp/combined/PG_VERSION"

# replication tools
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_receivewal -D /tmp --create-slot -S spread_phys
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_receivewal -D /tmp --drop-slot -S spread_phys
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_recvlogical -d testdb -S spread_logical --create-slot -P test_decoding
chroot "$rootfs" /usr/lib/postgresql/18/bin/pg_recvlogical -d testdb -S spread_logical --drop-slot

cleanup_postgresql
