#!/bin/bash
#spellchecker: ignore rootfs rbind rprivate epmd setsid pgid nodename

# Runs the broker and the tools as root inside chiselled rootfs'es. The cookie
# is found through HOME, and the node is named after localhost so that the
# broker and a cli in another rootfs both resolve it from the default hosts.
export HOME=/var/lib/rabbitmq
export RABBITMQ_NODENAME=rabbit@localhost
export RABBITMQ_LOGS=-

# the kernel file systems erlang needs; `prepare` made / rprivate, so the
# copies cannot take the host's /dev with them when clean-rootfs unmounts them
bind_kernel_fs() {
  local rootfs="$1"
  mkdir -p "$rootfs"/{dev,proc,sys}
  mount --rbind /dev "$rootfs/dev"
  mount --make-rprivate "$rootfs/dev"
  mount --bind /proc "$rootfs/proc"
  mount --bind /sys "$rootfs/sys"
}

# starts the broker in its own session and waits for it to finish booting;
# its log is $rootfs/broker.log and its process group is $broker_pgid
start_broker() {
  local rootfs="$1"
  bind_kernel_fs "$rootfs"
  setsid chroot "$rootfs" /usr/lib/rabbitmq/bin/rabbitmq-server </dev/null >"$rootfs/broker.log" 2>&1 &
  broker_pgid=$!
  for _ in $(seq 1 300); do
    grep -q 'Server startup complete' "$rootfs/broker.log" && return 0
    kill -0 "$broker_pgid" 2>/dev/null || break
    sleep 1
  done
  cat "$rootfs/broker.log" >&2
  return 1
}

# stops the broker's session if it is still up, and the epmd it leaves behind;
# afterwards nothing listens on the AMQP port any more
stop_broker() {
  local rootfs="$1"
  kill -TERM -- "-$broker_pgid" 2>/dev/null || true
  wait "$broker_pgid" 2>/dev/null || true
  chroot "$rootfs" /usr/bin/epmd -kill >/dev/null 2>&1 || true
  if exec 3<>/dev/tcp/127.0.0.1/5672 2>/dev/null; then
    exec 3>&- 3<&-
    return 1
  fi
}

# opens an AMQP 0-9-1 connection and expects Connection.Start back: a method
# frame (type 1) on channel 0 carrying class 10, method 10
assert_amqp() {
  local header
  exec 3<>/dev/tcp/127.0.0.1/5672
  printf 'AMQP\0\0\x09\x01' >&3
  header="$(timeout 30 head -c 11 <&3 | od -An -tx1 | tr -d ' \n')"
  exec 3>&- 3<&-
  test "${header:0:6}" = "010000"
  test "${header:14:8}" = "000a000a"
}

# prints the status line of a GET on the management api, as guest
http_status() {
  local path="$1" port="$2"
  exec 4<>/dev/tcp/127.0.0.1/"$port"
  printf 'GET %s HTTP/1.0\r\nAuthorization: Basic Z3Vlc3Q6Z3Vlc3Q=\r\n\r\n' "$path" >&4
  timeout 30 head -n1 <&4 | tr -d '\r'
  exec 4>&- 4<&-
}

# every application a shipped .app file lists is in the rootfs, either as a
# plugin directory or as an otp application the erlang-* essentials bring; the
# elixir applications come bundled in the cli escripts
assert_app_closure() {
  local rootfs="$1" plugins app_file app apps_seen=0
  local -a bundled=(eex elixir logger mix)
  plugins="$(echo "$rootfs"/usr/lib/rabbitmq/lib/rabbitmq_server-*/plugins)"
  for app_file in "$plugins"/*/ebin/*.app; do
    grep -q '{applications' "$app_file" || continue
    for app in $(tr -d '\n' <"$app_file" | sed -E 's/.*\{applications,[[:space:]]*\[([^]]*)\].*/\1/; s/[[:space:]]//g' | tr ',' ' '); do
      apps_seen=$((apps_seen + 1))
      [[ " ${bundled[*]} " == *" $app "* ]] && continue
      compgen -G "$plugins/$app-[0-9]*" >/dev/null && continue
      compgen -G "$rootfs/usr/lib/erlang/lib/$app-[0-9]*" >/dev/null && continue
      [ "$app" = erts ] && compgen -G "$rootfs/usr/lib/erlang/erts-[0-9]*" >/dev/null && continue
      return 1
    done
  done
  test "$apps_seen" -gt 0
}

# the names of the tools a slice ships, from its escript entries
cli_tools() {
  chisel info --release "$PROJECT_PATH" "$1" | grep -oE 'escript/[a-z-]+' | cut -d/ -f2 | sort -u
}
