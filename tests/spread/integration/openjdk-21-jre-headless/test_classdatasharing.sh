source "$(dirname "$0")/helpers.sh"

setup class-data-sharing
chroot . $java -XX:ArchiveClassesAtExit=archive.cds /Main.java
