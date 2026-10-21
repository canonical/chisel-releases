source "$(dirname "$0")/helpers.sh"

setup core
# /usr/lib/jvm/java-21-openjdk-*/bin/javac:
chroot . $home/javac /Main.java -d /
# /usr/lib/jvm/java-21-openjdk-*/bin/javadoc:
chroot . $home/javadoc /Main.java
# /usr/lib/jvm/java-21-openjdk-*/bin/javap:
chroot . $home/javap -l /Main.class
# /usr/lib/jvm/java-21-openjdk-*/bin/jdeprscan:
chroot . $home/jdeprscan --class-path . Main
# /usr/lib/jvm/java-21-openjdk-*/bin/jdeps:
chroot . $home/jdeps -m java.base
# /usr/lib/jvm/java-21-openjdk-*/bin/jimage:
chroot . $home/jimage info $home/../lib/modules
# /usr/lib/jvm/java-21-openjdk-*/bin/serialver:
chroot . $home/serialver -classpath / SerializableObject
