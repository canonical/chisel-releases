#!/bin/bash
# temporary: why does dotnet build hang on ppc64el? builds once with the 500-byte
# /dev/urandom file from prepare and once with the real devices bind-mounted, and
# reports how far each process got through /dev/urandom.
set -u
rootfs="$1"
ts() { date -u +%H:%M:%S; }

# processes chrooted into the rootfs: cpu ticks, threads, position in /dev/(u)random
probe() {
    local p pid fd tgt pos
    for p in /proc/[0-9]*; do
        [ "$(readlink "$p/root" 2>/dev/null)" = "$rootfs" ] || continue
        pid=${p#/proc/}
        pos=""
        for fd in "$p"/fd/*; do
            tgt=$(readlink "$fd" 2>/dev/null) || continue
            case "$tgt" in
                *dev/urandom|*dev/random) pos="$pos ${tgt##*/}(fd ${fd##*/})@$(awk '/^pos:/{print $2}' "$p/fdinfo/${fd##*/}" 2>/dev/null)";;
            esac
        done
        echo "  pid $pid cpu=$(awk '{print $14+$15}' "$p/stat") threads=$(ls "$p/task" | wc -l) rand:${pos:- none} cmd=$(tr '\0' ' ' < "$p/cmdline" | cut -c1-100)"
    done
}

# the busiest threads: state, cpu ticks, wchan and the syscall they sit in (nr and first arg)
threads() {
    local p pid t
    for p in /proc/[0-9]*; do
        [ "$(readlink "$p/root" 2>/dev/null)" = "$rootfs" ] || continue
        pid=${p#/proc/}
        for t in "$p"/task/*; do
            echo "$(awk '{print $14+$15, $3}' "$t/stat" 2>/dev/null) tid=${t##*/} pid=$pid wchan=$(cat "$t/wchan" 2>/dev/null) syscall=$(cut -d' ' -f1-2 "$t/syscall" 2>/dev/null)"
        done
    done | sort -rn | head -n 6 | sed 's/^/  ticks+state /'
}

kill_rootfs() {
    local p
    for p in /proc/[0-9]*; do
        [ "$(readlink "$p/root" 2>/dev/null)" = "$rootfs" ] && kill "-$1" "${p#/proc/}" 2>/dev/null
    done
}

result=""
build() {
    local label="$1" limit="$2" start pid rc log="/tmp/dotnet-build-$1.log"
    start=$(date +%s)
    echo "=== $(ts) build ($label)"
    chroot "$rootfs" /usr/bin/dotnet build /app_helloworld/app_helloworld.csproj --configuration Release \
        --no-restore --no-incremental -v:n > "$log" 2>&1 &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        sleep 5
        kill -0 "$pid" 2>/dev/null || break
        if [ $(( ($(date +%s) - start) % 30 )) -lt 5 ]; then
            echo "--- $(ts) +$(( $(date +%s) - start ))s"
            probe
        fi
        if [ $(( $(date +%s) - start )) -ge "$limit" ]; then
            echo "--- $(ts) TIMEOUT after ${limit}s"
            probe
            threads
            sleep 5
            echo "--- 5s later"
            threads
            echo "--- SIGQUIT (mono thread dump, if any)"
            kill_rootfs QUIT
            sleep 10
            kill_rootfs KILL
            wait "$pid"
            echo "--- last build output"
            tail -n 80 "$log"
            result="$result $label=timeout"
            return
        fi
    done
    wait "$pid"
    rc=$?
    echo "--- $(ts) rc=$rc after $(( $(date +%s) - start ))s"
    tail -n 25 "$log"
    result="$result $label=rc$rc"
}

ls -la "$rootfs/dev"
build fake500 300

echo "=== $(ts) real /dev/random and /dev/urandom"
for d in random urandom; do
    rm -f "$rootfs/dev/$d"
    touch "$rootfs/dev/$d"
    mount --bind "/dev/$d" "$rootfs/dev/$d"
done
ls -la "$rootfs/dev"
build realdev 600

chroot "$rootfs" /usr/bin/dotnet publish /app_helloworld/app_helloworld.csproj --no-restore --no-build \
    && chroot "$rootfs" /usr/bin/dotnet /app_helloworld/bin/Release/net8.0/publish/app_helloworld.dll \
    && result="$result run=ok" || result="$result run=failed"

for d in random urandom; do umount "$rootfs/dev/$d"; done
echo "=== RESULT $(dpkg --print-architecture) ${SPREAD_VARIANT}:$result"
