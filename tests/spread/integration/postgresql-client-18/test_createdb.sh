source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_createdb)"

createdb() { pg_run "$rootfs" createdb "$@"; }

expect_version "$rootfs" createdb
expect_output "Usage:" createdb --help

start_postgresql

expect_rc 0 createdb t_db
expect_sql 1 "SELECT count(*) FROM pg_database WHERE datname = 't_db'"

PGSSLMODE=require expect_rc 0 createdb t_db_ssl
