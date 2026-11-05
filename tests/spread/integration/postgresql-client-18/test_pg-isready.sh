source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-isready)"

isready() { pg_run "$rootfs" pg_isready "$@"; }

expect_version "$rootfs" pg_isready
expect_output "Usage:" isready --help

pg_ctlcluster 18 main stop || true

expect_rc 2 isready
expect_output "no response" isready

start_postgresql

expect_rc 0 isready
expect_output "accepting connections" isready

PGSSLMODE=require expect_rc 0 isready
