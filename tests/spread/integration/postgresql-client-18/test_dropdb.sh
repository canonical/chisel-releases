source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_dropdb)"

dropdb() { pg_run "$rootfs" dropdb "$@"; }

expect_version "$rootfs" dropdb
expect_output "Usage:" dropdb --help

start_postgresql

"$PG_BIN/createdb" t_db
"$PG_BIN/createdb" t_db_ssl

expect_rc 0 dropdb t_db
expect_sql 0 "SELECT count(*) FROM pg_database WHERE datname = 't_db'"

PGSSLMODE=require expect_rc 0 dropdb t_db_ssl
