setup() {
  rootfs="$(install-slices openjdk-17-jre-headless_$1 dash_bins)"
  cp *.java $rootfs/
  cp certificate.pem $rootfs/
  cd $rootfs
  mkdir -p proc/self
  java=/$(find "$rootfs" -name java -type f -printf '%P\n' -quit 2>/dev/null)
  ln -sf $java proc/self/exe
  chroot . $java -m jdk.compiler/com.sun.tools.javac.Main -d / *.java
  chroot . $java -m jdk.jartool/sun.tools.jar.Main cvf /test.jar *.java
  chroot . $java --version
}
