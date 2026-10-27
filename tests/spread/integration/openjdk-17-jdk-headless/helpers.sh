pids=()
cleanup() {
  for pid in "${pids[@]}"; do
    kill -- -"$pid" || true
  done
}
for sig in INT QUIT HUP TERM; do trap "cleanup; trap - $sig EXIT; kill -s $sig "'"$$"' "$sig"; done
trap cleanup EXIT

setup() {
  rootfs="$(install-slices openjdk-17-jdk-headless_$1 dash_bins base-passwd_data)"
  cp *.java $rootfs/
  cp all.policy $rootfs/

  cd $rootfs
  java=/$(find "$rootfs" -name java -type f -printf '%P\n' -quit 2>/dev/null)
  home=$(dirname $java)
  mkdir -p proc sys tmp
  mount --bind /proc proc
  mount --bind /sys sys
  mount --bind /tmp tmp
  chroot . $home/javac -d / *.java
}
