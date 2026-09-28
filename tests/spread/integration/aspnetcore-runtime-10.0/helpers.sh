# shellcheck shell=bash
#spellchecker: ignore rootfs setsid urandom

# Cut the given slices with the web app at /web and /proc mounted, and print
# the rootfs.
web_rootfs() {
  local rootfs
  rootfs="$(install-slices "$@")" || return 1
  cp -r web_helloworld/out "$rootfs/web" || return 1
  mkdir -p "$rootfs/proc" "$rootfs/dev" || return 1
  mount --bind /proc "$rootfs/proc" || return 1
  # the runtime seeds its random numbers from these
  head -c 10000 /dev/urandom > "$rootfs/dev/random" || return 1
  head -c 10000 /dev/urandom > "$rootfs/dev/urandom" || return 1
  echo "$rootfs"
}

# Start the given command in the rootfs, in its own process group, and wait
# until it answers on port 5108. The group goes when the test exits, since a
# leftover process keeps spread waiting on its output.
serve() {
  local rootfs="$1"
  shift
  setsid chroot "$rootfs" "$@" --urls=http://127.0.0.1:5108 &
  app_pid=$!
  # shellcheck disable=SC2064 # expand rootfs now
  trap "kill -- -\"\$app_pid\" 2>/dev/null || true; wait \"\$app_pid\" 2>/dev/null || true; umount '$rootfs/proc'" EXIT
  for _ in $(seq 60); do
    if curl -fsS http://127.0.0.1:5108/ > /dev/null 2>&1; then
      return 0
    fi
    if ! kill -0 "$app_pid" 2>/dev/null; then
      echo "the web app exited" >&2
      return 1
    fi
    sleep 1
  done
  echo "the web app never answered" >&2
  return 1
}
