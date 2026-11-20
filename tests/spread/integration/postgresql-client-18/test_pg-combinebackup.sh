source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-combinebackup)"

combinebackup() { pg_run "$rootfs" pg_combinebackup "$@"; }

create_tmp "$rootfs"

expect_version "$rootfs" pg_combinebackup
expect_output "Usage:" combinebackup --help

start_postgresql

"$PG_BIN/pg_basebackup" -D "$rootfs/tmp/full" --manifest-checksums=SHA256
sql "CREATE TABLE t AS SELECT generate_series(1, 1000) AS id"
"$PG_BIN/pg_basebackup" -D "$rootfs/tmp/incr" --incremental="$rootfs/tmp/full/backup_manifest" --manifest-checksums=SHA256

expect_rc 0 combinebackup /tmp/full /tmp/incr -o /tmp/combined --manifest-checksums=SHA256
[ -f "$rootfs/tmp/combined/PG_VERSION" ]
expect_rc 0 "$PG_BIN/pg_verifybackup" --no-parse-wal "$rootfs/tmp/combined"
