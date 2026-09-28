# shellcheck shell=bash
#spellchecker: ignore rootfs coreclr doclib urandom

# Cut the given slices with what the SDK expects around it: /proc, a /tmp,
# random devices, and a NuGet config that restores from nothing but the
# packs the slices ship. The test projects are copied to /hello and /doclib.
# The caller unmounts /proc.
sdk_rootfs() {
  local rootfs
  rootfs="$(install-slices base-passwd_data "$@")" || return 1
  mkdir -p "$rootfs/proc" "$rootfs/tmp" "$rootfs/dev" "$rootfs$HOME/.nuget/NuGet" || return 1
  mount --bind /proc "$rootfs/proc" || return 1
  head -c 10000 /dev/urandom > "$rootfs/dev/random" || return 1
  head -c 10000 /dev/urandom > "$rootfs/dev/urandom" || return 1
  cp NuGet.Config "$rootfs$HOME/.nuget/NuGet/NuGet.Config" || return 1
  cp -r hello doclib helloworld.fsx "$rootfs/" || return 1
  echo "$rootfs"
}

# The runtime identifier the SDK in the rootfs builds for.
sdk_rid() {
  local info
  info="$(chroot "$1" /usr/bin/dotnet --info)" || return 1
  awk '$1 == "RID:" { print $2; exit }' <<< "$info"
}

# coreclr runs on amd64 and arm64. ppc64el and s390x get the mono runtime,
# which has no single-file host and no ILLink pack.
is_coreclr() {
  case "$(dpkg --print-architecture)" in
    amd64 | arm64) return 0 ;;
    *) return 1 ;;
  esac
}
