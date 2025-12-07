#!/usr/bin/env bash

# --- paths (change via env or keep defaults) ---
CODEBASE="${CODEBASE:-$APPBENCH}"
REDIS_DIR="${REDIS_DIR:-$CODEBASE/redis-3.0.0/src}"
REDIS_SERVER="${REDIS_SERVER:-$REDIS_DIR/redis-server}"
REDIS_BENCH="${REDIS_BENCH:-$REDIS_DIR/redis-benchmark}"
REDIS_CLI="${REDIS_CLI:-$REDIS_DIR/redis-cli}"
REDIS_CONF="${REDIS_CONF:-$CODEBASE/redis-3.0.0/redis.conf}"
OUTPUT="${OUTPUT:-${OUTPUTDIR:-$PWD}/redis}"
FLUSH="${FLUSH:-1}"               # set FLUSH=1 to drop caches (needs sudo)

# --- REDIS run params (env overrides) ---
# KEY/DATASIZE patterns: R=random, S=sequential, G=Gaussian, Z=zipfian
HOST="${HOST:-127.0.0.1}"
REDIS_PORT="${PORT:-6500}"
REDIS_TESTTIME="${REDIS_TESTTIME:-60}"       # seconds
REDIS_DATASIZE_RANGE="${REDIS_DATASIZE_RANGE:-4-2048}" # bytes
REDIS_DATASIZE_PATTERN="${REDIS_DATA_SIZE_PATTERN:-R}"  
REDIS_KEY_MAXIMUM="${REDIS_KEY_MAXIMUM:-100000000}"
REDIS_KEY_PATTERN="${REDIS_KEY_PATTERN:-R:R}"
REDIS_RATIO="${REDIS_RATIO:-1:1}"           # read:set ratio
REDIS_OUTPUT="${REDIS_OUTPUT:-$OUTPUT/redis.out}"
REDIS_HISTOGRAM_FILE="${REDIS_HISTOGRAM_FILE:-$OUTPUT/latency.out}"


# --- MEMCACHED run params (env overrides) ---
MEMCACHED_PORT="${MEMCACHED_PORT:-11211}"

echo "OUTPUT: $OUTPUT"

mkdir -p "$OUTPUT"
SERVER_LOG="${OUTPUT%.log}.server.log"

flush() {
  [ "$FLUSH" = "1" ] && sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' || true
}

echo "==> starting redis-server on $HOST:$PORT"
flush
# start server in foreground, background the process; capture PID
# echo the exact command with variables expanded, then run it
echo "==> redis-server: ${APPPREFIX:+$APPPREFIX }$REDIS_SERVER ${REDIS_CONF:+$REDIS_CONF} --bind $HOST --port $PORT --daemonize no >$SERVER_LOG 2>&1 &"
${APPPREFIX:+$APPPREFIX }"$REDIS_SERVER" ${REDIS_CONF:+$REDIS_CONF} --bind "$HOST" --port "$REDIS_PORT" --daemonize no >"$SERVER_LOG" 2>&1 &
SRV_PID=$!

# wait until it answers PING (max ~10s)
for i in {1..50}; do
  "$REDIS_CLI" -h "$HOST" -p "$PORT" PING >/dev/null 2>&1 && break
  sleep 0.2
done

memtier_benchmark --port $REDIS_PORT --test-time=$REDIS_TESTTIME \
  --random-data --data-size-range=$REDIS_DATASIZE_RANGE \
  --data-size-pattern=$REDIS_DATASIZE_PATTERN --key-maximum=$REDIS_KEY_MAXIMUM \
  --ratio=$REDIS_RATIO --hide-histogram \
  --out-file=$REDIS_OUTPUT --hdr-file-prefix=$REDIS_HISTOGRAM_FILE 

kill "$SRV_PID" >/dev/null 2>&1 || true
wait "$SRV_PID" 2>/dev/null || true
echo "Done. Output: $REDIS_OUTPUT"


