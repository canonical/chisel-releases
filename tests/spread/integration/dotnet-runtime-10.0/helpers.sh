# shellcheck shell=bash
#spellchecker: ignore rootfs coreclr

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
