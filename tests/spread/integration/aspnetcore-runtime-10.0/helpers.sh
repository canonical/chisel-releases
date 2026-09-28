# shellcheck shell=bash
#spellchecker: ignore rootfs setsid urandom

# Build the web app into web_helloworld/out with the release's own SDK, in a
# rootfs of its own, so nothing is installed on the test host.
build_web() {
  local tools
  tools="$(install-slices base-passwd_data dotnet-sdk-10.0_minimal)" || return 1
  mkdir -p "$tools/proc" "$tools/tmp" "$tools/dev" "$tools/root/.nuget/NuGet" || return 1
  mount --bind /proc "$tools/proc" || return 1
  head -c 10000 /dev/urandom > "$tools/dev/random" || return 1
  head -c 10000 /dev/urandom > "$tools/dev/urandom" || return 1
  # restore from the packs the SDK ships, never the network
  cp NuGet.Config "$tools/root/.nuget/NuGet/NuGet.Config" || return 1
  cp -r web_helloworld "$tools/web" || return 1
  if ! DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 HOME=/root chroot "$tools" /usr/bin/dotnet publish \
    /web/Hello.csproj --configuration Release --no-self-contained --output /out; then
    umount "$tools/proc"
    return 1
  fi
  umount "$tools/proc" || return 1
  rm -rf web_helloworld/out
  cp -r "$tools/out" web_helloworld/out || return 1
  clean-rootfs "$tools"
}

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
