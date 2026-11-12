source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-amcheck)"

amcheck() { pg_run "$rootfs" pg_amcheck "$@"; }

expect_version "$rootfs" pg_amcheck
expect_output "Usage:" amcheck --help

start_postgresql

sql "CREATE EXTENSION amcheck"
sql "CREATE TABLE t (id int PRIMARY KEY)"
sql "INSERT INTO t SELECT generate_series(1, 100)"
expect_rc 0 amcheck

PGSSLMODE=require expect_rc 0 amcheck
