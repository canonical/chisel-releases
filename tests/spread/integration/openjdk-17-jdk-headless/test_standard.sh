source "$(dirname "$0")/helpers.sh"

setup standard
setsid nohup chroot . $java -cp / MonitoringTest > /dev/null 2>&1 &
pid=$!
pids+=("$pid")
timeout 20 sh -c "until chroot . $home/jcmd -l | grep -q MonitoringTest; do sleep 2; done"
# /usr/lib/jvm/java-17-openjdk-*/bin/jar:
# /usr/lib/jvm/java-17-openjdk-*/bin/jarsigner:
chroot . $home/jar cvf test.jar *.java
DNAME="CN=Sample Cert, OU=R&D, O=Company Ltd., L=Dublin 4, S=Dublin, C=IE"
chroot . $home/keytool -genkeypair -keystore foo -storepass barbar -keyalg RSA -dname "$DNAME" -alias foo
chroot . $home/jarsigner -keystore foo -storepass barbar test.jar foo
# /usr/lib/jvm/java-17-openjdk-*/bin/jdb:
chroot . /usr/bin/sh -c "echo run | $home/jdb Main.java"
# /usr/lib/jvm/java-17-openjdk-*/bin/jcmd:
chroot . $home/jcmd MonitoringTest VM.version
# /usr/lib/jvm/java-17-openjdk-*/bin/jhsdb:
if [ -f $home/jhsdb ]; then
  chroot . $home/jhsdb jstack --pid $pid
fi
# /usr/lib/jvm/java-17-openjdk-*/bin/jfr:
chroot . $home/jcmd $pid JFR.start name=recording maxsize=1MB
chroot . $home/jcmd $pid JFR.dump name=recording filename=/tmp/recording.jfr
chroot . $home/jfr print /tmp/recording.jfr > /dev/null
# /usr/lib/jvm/java-17-openjdk-*/bin/jinfo:
chroot . $home/jinfo $pid
# /usr/lib/jvm/java-17-openjdk-*/bin/jrunscript:
chroot . $home/jrunscript -q
# /usr/lib/jvm/java-17-openjdk-*/bin/jshell:
chroot . /usr/bin/sh -c "echo 'System.out.println(\"hello world\")' | $home/jshell"
# /usr/lib/jvm/java-17-openjdk-*/bin/jstack:
chroot . $home/jstack $pid
# /usr/lib/jvm/java-17-openjdk-*/bin/jstat:
chroot . $home/jstat -gc $pid
# /usr/lib/jvm/java-17-openjdk-*/bin/jstatd:
setsid nohup chroot . $home/jstatd -J-Djava.security.policy=all.policy > ./jstatd.log &
pids+=($!)
for retry in 0 1 2 3 4 5; do
  if [ $retry -eq 5 ]; then
    exit 1
  fi
  grep -q "bound to /JStatRemoteHost" "jstatd.log" && break
  sleep 10
done
