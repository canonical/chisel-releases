#!/usr/bin/env bash

prepare_postgresql() {
  local rootfs="$1"

  mkdir -p "$rootfs/tmp"
  chmod 1777 "$rootfs/tmp"

  cat > /etc/postgresql/18/main/conf.d/spread.conf <<EOF
wal_level = logical
summarize_wal = on
EOF

  cp pg_hba.conf /etc/postgresql/18/main/pg_hba.conf

  export PGUSER=postgres
  export PGHOST=127.0.0.1
}

start_postgresql() {
  pg_ctlcluster 18 main restart
  for i in $(seq 30); do
    pg_isready -q && break
    sleep 1
  done
  pg_isready
}

cleanup_postgresql() {
  # cleanup
  /usr/lib/postgresql/18/bin/dropdb testdb
  /usr/lib/postgresql/18/bin/dropuser testuser

  pg_ctlcluster 18 main stop || true
}
