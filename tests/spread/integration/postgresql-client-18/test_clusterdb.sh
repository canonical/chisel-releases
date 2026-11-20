source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_clusterdb)"

clusterdb() { pg_run "$rootfs" clusterdb "$@"; }

expect_version "$rootfs" clusterdb
expect_output "Usage:" clusterdb --help

start_postgresql

order() { sql "SELECT string_agg(id::text, ',' ORDER BY ctid) FROM $1"; }
make_clustered() {
  sql "CREATE TABLE $1 (id int)"
  sql "CREATE INDEX $1_idx ON $1 (id)"
  sql "INSERT INTO $1 VALUES (3), (1), (2)"
  sql "CLUSTER $1 USING $1_idx"
  sql "INSERT INTO $1 VALUES (0)"
}

make_clustered t1
[ "$(order t1)" = "1,2,3,0" ]
expect_rc 0 clusterdb
[ "$(order t1)" = "0,1,2,3" ]

make_clustered t2
PGSSLMODE=require expect_rc 0 clusterdb
[ "$(order t2)" = "0,1,2,3" ]
