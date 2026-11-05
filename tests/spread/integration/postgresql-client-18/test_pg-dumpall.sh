source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-dumpall)"

dumpall() { pg_run "$rootfs" pg_dumpall "$@"; }

expect_version "$rootfs" pg_dumpall
expect_output "Usage:" dumpall --help

start_postgresql

sql "CREATE TABLE t AS SELECT 1 AS id"

expect_output "CREATE ROLE postgres" dumpall --globals-only

expect_output "CREATE TABLE public.t " dumpall

PGSSLMODE=require expect_rc 0 dumpall --globals-only
