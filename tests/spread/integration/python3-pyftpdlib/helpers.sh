#!/usr/bin/env bash

function wait_for_ftp(){
  sleep 0.3
  while ! nc -z 127.0.0.1 2121
  do
    test -d /proc/$pyftpdlib_pid || (echo "pyftpdlib exited early"; exit 1)
    sleep 1
  done
}

function cleanup(){
  [[ -n "${pyftpdlib_pid:-}" ]] || return 0
  while [[ -d /proc/$pyftpdlib_pid ]]; do
    kill $pyftpdlib_pid || true
    sleep 0.1
  done
}

# A rootfs with /dev and a file to serve under /srv.
function prepare_srv(){
  mkdir "$1/dev"
  mount --bind /dev "$1/dev"
  mkdir -p "$1/srv/subdir"
  echo "Test file" > "$1/srv/subdir/test-file"
}
