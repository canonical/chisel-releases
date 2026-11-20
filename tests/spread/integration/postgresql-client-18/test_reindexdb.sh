source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_reindexdb)"

reindexdb() { pg_run "$rootfs" reindexdb "$@"; }

expect_version "$rootfs" reindexdb
expect_output "Usage:" reindexdb --help

start_postgresql

sql "CREATE TABLE t (id int)"
sql "CREATE INDEX t_idx ON t (id)"
before="$(sql "SELECT relfilenode FROM pg_class WHERE relname = 't_idx'")"
expect_rc 0 reindexdb
after="$(sql "SELECT relfilenode FROM pg_class WHERE relname = 't_idx'")"
[ "$before" != "$after" ]

PGSSLMODE=require expect_rc 0 reindexdb
