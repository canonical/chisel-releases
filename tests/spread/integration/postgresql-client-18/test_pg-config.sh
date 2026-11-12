source "$(dirname "$0")/helpers.sh"

rootfs="$(install-slices postgresql-client-18_pg-config)"

config() { pg_run "$rootfs" pg_config "$@"; }

expect_version "$rootfs" pg_config
expect_output "Usage:" config --help
expect_output "/usr/lib/postgresql/18/bin" config --bindir
