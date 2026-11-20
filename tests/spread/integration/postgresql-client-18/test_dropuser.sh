source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_dropuser)"

dropuser() { pg_run "$rootfs" dropuser "$@"; }

expect_version "$rootfs" dropuser
expect_output "Usage:" dropuser --help

start_postgresql

sql "CREATE ROLE t_user"
sql "CREATE ROLE t_user_ssl"

expect_rc 0 dropuser t_user
expect_sql 0 "SELECT count(*) FROM pg_roles WHERE rolname = 't_user'"

PGSSLMODE=require expect_rc 0 dropuser t_user_ssl
