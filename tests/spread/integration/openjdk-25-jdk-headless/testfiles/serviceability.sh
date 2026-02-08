#!/bin/sh
# This shell script runs within the chroot environment
# The lingering java processing are reaped by the parent
set -ex

JAVA_HOME="$1"
shift
COMMAND="$1"
shift
ARGS=$*

"$JAVA_HOME/bin/java" /MonitoringTest.java &
pid="$!"
"$JAVA_HOME/bin/$COMMAND" $ARGS "$pid"
