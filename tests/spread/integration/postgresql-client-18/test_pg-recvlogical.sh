source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-recvlogical)"

recvlogical() { pg_run "$rootfs" pg_recvlogical "$@"; }

expect_version "$rootfs" pg_recvlogical
expect_output "Usage:" recvlogical --help

start_postgresql

sql "CREATE TABLE t (id int)"
expect_rc 0 recvlogical -d postgres -S t_slot -P test_decoding --create-slot
sql "INSERT INTO t VALUES (1)"
lsn="$(sql "SELECT pg_current_wal_lsn()")"
expect_output "table public.t: INSERT" \
  recvlogical -d postgres -S t_slot --start --endpos="$lsn" -f -
expect_rc 0 recvlogical -d postgres -S t_slot --drop-slot

export PGSSLMODE=require
expect_rc 0 recvlogical -d postgres -S t_slot_ssl -P test_decoding --create-slot
sql "INSERT INTO t VALUES (2)"
lsn="$(sql "SELECT pg_current_wal_lsn()")"
expect_output "table public.t: INSERT: id\[integer\]:2" \
  recvlogical -d postgres -S t_slot_ssl --start --endpos="$lsn" -f -
expect_rc 0 recvlogical -d postgres -S t_slot_ssl --drop-slot
unset PGSSLMODE
