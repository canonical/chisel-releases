# shellcheck shell=bash
#spellchecker: ignore rootfs coreclr

# The native directory of the apphost pack, as seen from inside the rootfs.
native_dir() {
  local dir
  dir="$(echo "$1"/usr/lib/dotnet/packs/Microsoft.NETCore.App.Host.*/10.0.*/runtimes/*/native)"
  echo "${dir#"$1"}"
}

# coreclr runs on amd64 and arm64. ppc64el and s390x get the mono runtime,
# which has no single-file host.
is_coreclr() {
  case "$(dpkg --print-architecture)" in
    amd64 | arm64) return 0 ;;
    *) return 1 ;;
  esac
}
