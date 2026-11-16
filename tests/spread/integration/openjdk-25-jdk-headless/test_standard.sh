#!/bin/bash -ex

if [ -z "$ROOTFS" ] || [ -z "$JAVA_HOME" ]; then
  echo "Usage: $0 ROOTFS JAVA_HOME"
  exit 1
fi

pids=()
cleanup() {
    for pid in "${pids[@]}"; do
        kill -- -"$pid" 2>/dev/null || true
    done
}

for sig in INT QUIT HUP TERM; do trap "cleanup; trap - $sig EXIT; kill -s $sig "'"$$"' "$sig"; done
trap cleanup EXIT

setsid nohup chroot "$ROOTFS" "$JAVA_HOME/bin/java" /MonitoringTest.java > /dev/null 2>&1 &
pid=$!
pids+=("$pid")
timeout 20 sh -c 'until chroot "$ROOTFS" "$JAVA_HOME/bin/jcmd" -l | grep -q MonitoringTest; do sleep 2; done'

# /usr/lib/jvm/java-25-openjdk-*/bin/jar:
# /usr/lib/jvm/java-25-openjdk-*/bin/jarsigner:
chroot "$ROOTFS" "$JAVA_HOME/bin/jar" cvf test.jar /Main.java
DNAME="CN=Sample Cert, OU=R&D, O=Company Ltd., L=Dublin 4, S=Dublin, C=IE"
chroot "$ROOTFS" "$JAVA_HOME/bin/keytool" -genkeypair -keystore foo -storepass barbar -keyalg RSA -dname "$DNAME" -alias foo
chroot "$ROOTFS" "$JAVA_HOME/bin/jarsigner" -keystore foo -storepass barbar test.jar foo

# /usr/lib/jvm/java-25-openjdk-*/bin/jdb:
chroot "$ROOTFS" /usr/bin/sh -c 'echo run | "$JAVA_HOME/bin/jdb" Main.java'

# /usr/lib/jvm/java-25-openjdk-*/bin/jcmd:
chroot "$ROOTFS" "$JAVA_HOME/bin/jcmd" "$pid" VM.version

# /usr/lib/jvm/java-25-openjdk-*/bin/jhsdb:
if [ -f "$JAVA_HOME/bin/jhsdb" ]; then
    setsid chroot "$ROOTFS" /usr/bin/sh /serviceability.sh "$JAVA_HOME" jhsdb jstack --pid &
    pids+=($!)
    wait $!
fi

# /usr/lib/jvm/java-25-openjdk-*/bin/jfr:
chroot "$ROOTFS" "$JAVA_HOME/bin/jcmd" "$pid" JFR.start name=recording filename=/recording.jfr maxsize=1MB
chroot "$ROOTFS" "$JAVA_HOME/bin/jcmd" "$pid" JFR.stop
chroot "$ROOTFS" "$JAVA_HOME/bin/jcmd" "$pid" JFR.dump name=recording  filename=/recording.jfr
chroot "$ROOTFS" "$JAVA_HOME/bin/jfr" print recording.jfr > /dev/null

# /usr/lib/jvm/java-25-openjdk-*/bin/jinfo:
chroot "$ROOTFS" "$JAVA_HOME/bin/jinfo" "$pid"

# /usr/lib/jvm/java-25-openjdk-*/bin/jshell:
chroot "$ROOTFS" /usr/bin/sh -c "echo 'System.out.println(\"hello world\")' | '$JAVA_HOME/bin/jshell'"

# /usr/lib/jvm/java-25-openjdk-*/bin/jmap:
setsid chroot "$ROOTFS" /usr/bin/sh /serviceability.sh "$JAVA_HOME" jmap -clstats &
pids+=($!)
wait $!

# /usr/lib/jvm/java-25-openjdk-*/bin/jnativescan:
mkdir "$ROOTFS/nativetest"
cp "$ROOTFS/Native.class" "$ROOTFS/nativetest/"
chroot "$ROOTFS" "$JAVA_HOME/bin/jnativescan" -class-path /nativetest | grep -q ALL-UNNAMED

# /usr/lib/jvm/java-25-openjdk-*/bin/jps:
chroot "$ROOTFS" "$JAVA_HOME/bin/jps" -l

# /usr/lib/jvm/java-25-openjdk-*/bin/jstack:
setsid chroot "$ROOTFS" /usr/bin/sh /serviceability.sh "$JAVA_HOME" jstack &
pids+=($!)
wait $!

# /usr/lib/jvm/java-25-openjdk-*/bin/jstat:
chroot "$ROOTFS" "$JAVA_HOME/bin/jstat" -gc "$pid"

# /usr/lib/jvm/java-25-openjdk-*/bin/jstatd:
setsid nohup chroot "$ROOTFS" "$JAVA_HOME/bin/jstatd" > ./jstatd.log &
pids+=($!)
timeout 20 sh -c 'until grep -q "bound to /JStatRemoteHost" jstatd.log; do sleep 2; done'

# /usr/lib/jvm/java-25-openjdk-amd64/bin/jwebserver
setsid nohup chroot "$ROOTFS" "$JAVA_HOME/bin/jwebserver" &
pids+=($!)
curl --retry 10 --retry-delay 2 --retry-connrefused http://127.0.0.1:8000

# /usr/lib/jvm/java-25-openjdk-*/bin/jrunscript:
chroot "$ROOTFS" "$JAVA_HOME/bin/jrunscript" -q
