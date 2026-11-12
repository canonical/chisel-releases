source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-verifybackup)"

verifybackup() { pg_run "$rootfs" pg_verifybackup "$@"; }

create_tmp "$rootfs"

expect_version "$rootfs" pg_verifybackup
expect_output "Usage:" verifybackup --help

start_postgresql

for c in gzip lz4 zstd; do
  "$PG_BIN/pg_basebackup" -D "$rootfs/tmp/bb_$c" -Ft --compress=client-$c --manifest-checksums=SHA256
  # TODO: test `verifybackup /tmp/bb_$c` when postgresql-18 slice is created
  expect_rc 0 verifybackup --no-parse-wal /tmp/bb_$c
done
