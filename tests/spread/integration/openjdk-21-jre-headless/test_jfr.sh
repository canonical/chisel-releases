source "$(dirname "$0")/helpers.sh"

setup jfr
chroot . $java -XX:+FlightRecorder -XX:StartFlightRecording=duration=60s,filename=dump.jfr /Main.java
