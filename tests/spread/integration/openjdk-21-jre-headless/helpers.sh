setup() {
  rootfs="$(install-slices openjdk-21-jre-headless_$1)"
  cp *.java $rootfs/
  cd $rootfs
  mkdir -p proc/self
  java=/$(find "$rootfs" -name java -type f -printf '%P\n' -quit 2>/dev/null)
  ln -sf $java proc/self/exe
  chroot . $java -m jdk.compiler/com.sun.tools.javac.Main -d / *.java
  chroot . $java --version
}
