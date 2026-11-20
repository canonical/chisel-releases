source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_vacuumdb)"

vacuumdb() { pg_run "$rootfs" vacuumdb "$@"; }

expect_version "$rootfs" vacuumdb
expect_output "Usage:" vacuumdb --help

start_postgresql

sql "CREATE TABLE t AS SELECT generate_series(1, 100) AS id"
expect_sql 0 "SELECT count(*) FROM pg_stats WHERE tablename = 't'"
expect_rc 0 vacuumdb --analyze-only
expect_sql t "SELECT count(*) > 0 FROM pg_stats WHERE tablename = 't'"

PGSSLMODE=require expect_rc 0 vacuumdb --analyze
