source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-restore)"

restore() { pg_run "$rootfs" pg_restore "$@"; }

create_tmp "$rootfs"

expect_version "$rootfs" pg_restore
expect_output "Usage:" restore --help

start_postgresql

sql "CREATE TABLE dumptable AS SELECT generate_series(1, 1000) AS id"

for c in none gzip lz4 zstd; do
  "$PG_BIN/pg_dump" -Fc --compress=$c -f "$rootfs/tmp/d.$c" postgres
  "$PG_BIN/createdb" "r_$c"
  expect_rc 0 restore -d "r_$c" /tmp/d.$c
  [ "$("$PG_BIN/psql" -Atq -d "r_$c" -c "SELECT count(*) FROM dumptable")" = 1000 ]
done

expect_output "CREATE TABLE public.dumptable" restore -f - /tmp/d.gzip

"$PG_BIN/createdb" r_ssl
PGSSLMODE=require expect_rc 0 restore -d r_ssl /tmp/d.gzip
