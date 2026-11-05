source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_psql)"

psql() { pg_run "$rootfs" psql "$@"; }

create_tmp "$rootfs"

expect_version "$rootfs" psql
expect_output "Usage:" psql --help

start_postgresql

expect_output "^42$" psql -Atq -c "SELECT 42"

expect_output "^43$" psql -Atq <<<"SELECT 43;"

echo "SELECT 44;" > "$rootfs/tmp/q.sql"
expect_output "^44$" psql -Atq -f /tmp/q.sql

PGSSLMODE=require expect_output "^45$" psql -Atq -c "SELECT 45"
