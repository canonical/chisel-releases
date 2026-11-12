#!/usr/bin/env bash
PG_BIN="/usr/lib/postgresql/18/bin"

start_postgresql() {
  pg_ctlcluster 18 main restart
  for i in $(seq 30); do
    pg_isready -q && break
    sleep 1
  done
  pg_isready
}

create_tmp() {
  local rootfs="$1"
  mkdir -p "$rootfs/tmp"
  chmod 1777 "$rootfs/tmp"
}

pg_run() {
  local rootfs="$1" tool="$2"
  shift 2
  chroot "$rootfs" "$PG_BIN/$tool" "$@"
}

sql() {
  "$PG_BIN/psql" -Atq -d postgres -c "$1"
}

expect_rc() {
  local expected="$1"; shift
  local rc=0 out
  out="$(set +x; "$@" 2>&1)" || rc=$?
  if [ "$rc" -ne "$expected" ]; then
    echo "FAIL: '$*' exited $rc, expected $expected:" >&2
    echo "$out" >&2
    exit 1
  fi
}

expect_output() {
  local pattern="$1"; shift
  local out
  out="$(set +x; "$@" 2>&1 || true)"
  if ! grep -Eq "$pattern" <<<"$out"; then
    echo "FAIL: '$*' output did not match '$pattern':" >&2
    echo "$out" >&2
    exit 1
  fi
}

expect_version() {
  expect_output "PostgreSQL.* 18" pg_run "$1" "$2" --version
}

expect_sql() {
  local expected="$1" out
  out="$(sql "$2")"
  if [ "$out" != "$expected" ]; then
    echo "FAIL: '$2' returned '$out', expected '$expected'" >&2
    exit 1
  fi
}
