source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_createuser)"

createuser() { pg_run "$rootfs" createuser "$@"; }

expect_version "$rootfs" createuser
expect_output "Usage:" createuser --help

start_postgresql

expect_rc 0 createuser t_user
expect_sql 1 "SELECT count(*) FROM pg_roles WHERE rolname = 't_user'"

PGSSLMODE=require expect_rc 0 createuser t_user_ssl
