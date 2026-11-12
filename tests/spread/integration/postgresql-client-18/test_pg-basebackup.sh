source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-basebackup)"

basebackup() { pg_run "$rootfs" pg_basebackup "$@"; }

create_tmp "$rootfs"

expect_version "$rootfs" pg_basebackup
expect_output "Usage:" basebackup --help

start_postgresql

expect_rc 0 basebackup -D /tmp/plain
[ -f "$rootfs/tmp/plain/PG_VERSION" ]

# Compression libs
expect_rc 0 basebackup -D /tmp/gz  -Ft --compress=client-gzip
expect_rc 0 basebackup -D /tmp/lz4 -Ft --compress=client-lz4
expect_rc 0 basebackup -D /tmp/zst -Ft --compress=client-zstd
[ -s "$rootfs/tmp/gz/base.tar.gz" ]
[ -s "$rootfs/tmp/lz4/base.tar.lz4" ]
[ -s "$rootfs/tmp/zst/base.tar.zst" ]

PGSSLMODE=require expect_rc 0 basebackup -D /tmp/ssl
