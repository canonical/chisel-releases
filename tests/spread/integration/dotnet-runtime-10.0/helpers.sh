# shellcheck shell=bash
#spellchecker: ignore rootfs coreclr urandom

# Build the probe app into app_helloworld/out with the release's own SDK, in
# a rootfs of its own, so nothing is installed on the test host.
build_probe() {
  local tools
  tools="$(install-slices base-passwd_data dotnet-sdk-10.0_minimal)" || return 1
  mkdir -p "$tools/proc" "$tools/tmp" "$tools/dev" "$tools/root/.nuget/NuGet" || return 1
  mount --bind /proc "$tools/proc" || return 1
  head -c 10000 /dev/urandom > "$tools/dev/random" || return 1
  head -c 10000 /dev/urandom > "$tools/dev/urandom" || return 1
  # restore from the packs the SDK ships, never the network
  cp NuGet.Config "$tools/root/.nuget/NuGet/NuGet.Config" || return 1
  cp -r app_helloworld "$tools/app" || return 1
  if ! DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 HOME=/root chroot "$tools" /usr/bin/dotnet publish \
    /app/Hello.csproj --configuration Release --no-self-contained --output /out; then
    umount "$tools/proc"
    return 1
  fi
  umount "$tools/proc" || return 1
  rm -rf app_helloworld/out
  cp -r "$tools/out" app_helloworld/out || return 1
  clean-rootfs "$tools"
}

# Cut the given slices with the probe app at /app and /proc mounted, and
# print the rootfs. The caller unmounts /proc.
probe_rootfs() {
  local rootfs
  rootfs="$(install-slices "$@")" || return 1
  cp -r app_helloworld/out "$rootfs/app" || return 1
  mkdir -p "$rootfs/proc" "$rootfs/tmp" || return 1
  mount --bind /proc "$rootfs/proc" || return 1
  echo "$rootfs"
}

# The shared framework directory of a rootfs.
framework_dir() {
  echo "$1"/usr/lib/dotnet/shared/Microsoft.NETCore.App/10.0.*
}

# coreclr runs on amd64 and arm64. ppc64el and s390x get the mono runtime,
# which has no tracing provider, debugger interface or crash dump writer.
is_coreclr() {
  case "$(dpkg --print-architecture)" in
    amd64 | arm64) return 0 ;;
    *) return 1 ;;
  esac
}
