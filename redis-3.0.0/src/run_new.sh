#!/usr/bin/env bash
# minimal_redis_bench.sh — simple, configurable, few lines

# --- paths (change via env or keep defaults) ---
CODEBASE="${CODEBASE:-$APPBENCH}"
REDIS_DIR="${REDIS_DIR:-$CODEBASE/redis-3.0.0/src}"
REDIS_SERVER="${REDIS_SERVER:-$REDIS_DIR/redis-server}"
REDIS_BENCH="${REDIS_BENCH:-$REDIS_DIR/redis-benchmark}"
REDIS_CLI="${REDIS_CLI:-$REDIS_DIR/redis-cli}"
REDIS_CONF="${REDIS_CONF:-$CODEBASE/redis-3.0.0/redis.conf}"

# --- run params (env overrides) ---
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-6500}"
KEYSPACE="${KEYSPACE:-2000000}"    # -r
REQUESTS="${REQUESTS:-4000000}"   # -n
CLIENTS="${CLIENTS:-200}"          # -c
PIPELINE="${PIPELINE:-64}"        # -P
DATASIZE="${DATASIZE:-2048}"      # -d (bytes)
TESTS="${TESTS:-get,set}"         # -t
#OUTPUT="${OUTPUT:-${OUTPUTDIR:-$PWD}/redis_bench_$(date +%Y%m%d-%H%M%S).log}"
OUTPUT="${OUTPUT:-${OUTPUTDIR:-$PWD}/redis}"
APPPREFIX="${APPPREFIX:-}"        # e.g., $QUARTZSCRIPTS/runenv.sh
FLUSH="${FLUSH:-0}"               # set FLUSH=1 to drop caches (needs sudo)

# --- cgroup params ---
CG_ENABLE="${CG_ENABLE:-true}"    # set to "true" to enable cgroups
MEM="${MEM:-60}"                  # max memory in GB for redis-benchmark - default: 60GB
CPUS="${CPUS:-0-15}"               # CPU cores for redis-benchmark - default: cores 0 to 15
GB=1024*1024*1024

echo "Cgroup enabled: $CG_ENABLE, MEM: $MEM GB, CPUS: $CPUS"
# --- cgroup setup ---
LAUNCH() {
    echo "$*"
    eval "$*"
}
have_cgv2() { [[ -f "/sys/fs/cgroup/cgroup.controllers" ]]; }
cg_init_tree() {
    [[ "$CG_ENABLE" == "true" ]] || return 0
    have_cgv2 || { echo "WARN: no cgroup v2; proceeding without cgroups"; return 0; }
    if [[ ! -d "/sys/fs/cgroup/exp" ]]; then
        LAUNCH "sudo mkdir -p /sys/fs/cgroup/exp"
        LAUNCH "echo '+memory +cpu +cpuset' | sudo tee /sys/fs/cgroup/cgroup.subtree_control >/dev/null || true"
        LAUNCH "echo '+memory +cpu +cpuset' | sudo tee /sys/fs/cgroup/exp/cgroup.subtree_control >/dev/null || true"
    fi
}

cg_make_grp() {
    local grp="$1" mem_gb="$2" cpus_csv="$3"
    echo "grp=$grp, mem_gb=$mem_gb, cpus_csv=$cpus_csv"
    [[ "$CG_ENABLE" == "true" ]] || return 0
    have_cgv2 || return 0
    local path="/sys/fs/cgroup/$USER-group-$grp"
    LAUNCH "sudo mkdir -p '$path'"
    if [[ -n "$mem_gb" && "$mem_gb" != "0" ]]; then
        local bytes; bytes=$((mem_gb*GB))
        # LAUNCH "echo $bytes | sudo tee '$path/memory.high' >/dev/null"
        LAUNCH "echo $bytes | sudo tee '$path/memory.max'  >/dev/null"
    fi
    if [[ -n "$cpus_csv" && "$cpus_csv" != "0" ]]; then
        echo "[[[Setting cpuset for $grp]]]"
        LAUNCH "echo '$cpus_csv' | sudo tee '$path/cpuset.cpus'  >/dev/null || true"
    fi
    echo "SET CGROUP!!!"
}

# --- main script ---

cg_init_tree
cg_make_grp "redis" "$MEM" "$CPUS"

mkdir -p "$(dirname "$OUTPUT")"
SERVER_LOG="${OUTPUT%.log}.server.log"

flush() {
  [ "$FLUSH" = "1" ] && sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' || true
}

echo "==> starting redis-server on $HOST:$PORT"
flush
# start server in foreground, background the process; capture PID
${APPPREFIX:+$APPPREFIX }"$REDIS_SERVER" ${REDIS_CONF:+$REDIS_CONF} \
  --bind "$HOST" --port "$PORT" --daemonize no >"$SERVER_LOG" 2>&1 &
SRV_PID=$!

# wait until it answers PING (max ~10s)
for i in {1..50}; do
  "$REDIS_CLI" -h "$HOST" -p "$PORT" PING >/dev/null 2>&1 && break
  sleep 0.2
done

echo "==> running redis-benchmark (logging to $OUTPUT)"
if [[ "$CG_ENABLE" == "true" && -d "/sys/fs/cgroup/$USER-group-redis" ]]; then
    echo "Using cgroup for redis-benchmark."
    sudo cgexec -g cpu,memory:$USER-group-redis \
        /usr/bin/time -f 'TOTAL WALL CLOCK TIME(SEC): %e' \
        ${APPPREFIX:+$APPPREFIX }"$REDIS_BENCH" \
        -t "$TESTS" -n "$REQUESTS" -r "$KEYSPACE" -c "$CLIENTS" -P "$PIPELINE" -d "$DATASIZE" \
        -q -h "$HOST" -p "$PORT" >>"$OUTPUT" 2>&1
else
    echo "Not using cgroup for redis-benchmark."
    # echo the command that will be executed next (for easier debugging)
    echo "Command to run:"
    echo "/usr/bin/time -f 'TOTAL WALL CLOCK TIME(SEC): %e' ${APPPREFIX:+$APPPREFIX }\"$REDIS_BENCH\" -t \"$TESTS\" -n \"$REQUESTS\" -r \"$KEYSPACE\" -c \"$CLIENTS\" -P \"$PIPELINE\" -d \"$DATASIZE\" -q -h \"$HOST\" -p \"$PORT\" >>\"$OUTPUT\" 2>&1"
    /usr/bin/time -f 'TOTAL WALL CLOCK TIME(SEC): %e' \
        ${APPPREFIX:+$APPPREFIX }"$REDIS_BENCH" \
        -t "$TESTS" -n "$REQUESTS" -r "$KEYSPACE" -c "$CLIENTS" -P "$PIPELINE" -d "$DATASIZE" \
        -q -h "$HOST" -p "$PORT" >>"$OUTPUT" 2>&1

    echo "Finished redis-benchmark without cgroup."
fi

echo "==> stopping redis-server (pid $SRV_PID)"
kill "$SRV_PID" >/dev/null 2>&1 || true
wait "$SRV_PID" 2>/dev/null || true

echo "Done. Output: $OUTPUT"
