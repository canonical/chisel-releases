source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-receivewal)"

receivewal() { pg_run "$rootfs" pg_receivewal "$@"; }

receive() {
  local name="$1"; shift
  mkdir "$rootfs/tmp/wal_$name"
  expect_rc 0 receivewal -D "/tmp/wal_$name" -S "slot_$name" --create-slot
  sql "CREATE TABLE t_$name AS SELECT generate_series(1, 1000) AS id"
  sql "SELECT pg_switch_wal()"
  local lsn
  lsn="$(sql "SELECT pg_current_wal_lsn()")"
  expect_rc 0 receivewal -D "/tmp/wal_$name" -S "slot_$name" --endpos="$lsn" --no-loop "$@"
  expect_rc 0 receivewal -S "slot_$name" --drop-slot
}

create_tmp "$rootfs"

expect_version "$rootfs" pg_receivewal
expect_output "Usage:" receivewal --help

start_postgresql

receive plain
[ -n "$(ls "$rootfs/tmp/wal_plain")" ]

receive gzip --compress=gzip
ls "$rootfs/tmp/wal_gzip" | grep -q '\.gz'

receive lz4 --compress=lz4
ls "$rootfs/tmp/wal_lz4" | grep -q '\.lz4'

PGSSLMODE=require receive ssl
[ -n "$(ls "$rootfs/tmp/wal_ssl")" ]
