source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-dump)"

dump() { pg_run "$rootfs" pg_dump "$@"; }

create_tmp "$rootfs"

expect_version "$rootfs" pg_dump
expect_output "Usage:" dump --help

start_postgresql

sql "CREATE TABLE dumptable AS SELECT generate_series(1, 1000) AS id"

expect_output "CREATE TABLE public.dumptable" dump postgres

# Compression libs: zlib, liblz4, libzstd
for c in gzip lz4 zstd; do
  expect_rc 0 dump -Fc --compress=$c -f /tmp/d.$c postgres
  expect_output "dumptable" "$PG_BIN/pg_restore" -l "$rootfs/tmp/d.$c"
done

PGSSLMODE=require expect_output "CREATE TABLE" dump postgres
