#!/usr/bin/env bash
set -euo pipefail

# --- paths (change via env or keep defaults) ---
CODEBASE="${CODEBASE:-$APPBENCH}"
MEMCACHED_DIR="${MEMCACHED_DIR:-$CODEBASE/MEMCACHED-1.6.39}"
# MEMCACHED_CONF="${MEMCACHED_CONF:-$CODEBASE/MEMCACHED-1.6.39/MEMCACHED.conf}"
OUTPUT="${OUTPUT:-${OUTPUTDIR:-$PWD}/MEMCACHED}"
FLUSH="${FLUSH:-1}"               # set FLUSH=1 to drop caches (needs sudo)

# --- MEMCACHED run params (env overrides) ---
# KEY/DATASIZE patterns: R=random, S=sequential, G=Gaussian, Z=zipfian
HOST="${HOST:-127.0.0.1}"
PROTOCOL="${PROTOCOL:-memcache_binary}"
# Performance params
CLIENTS="${CLIENTS:-1024}"
THREADS="${THREADS:-4}"
PIPELINE="${PIPELINE:-10}"

# Number of Loaded Client-Server Pairs
LOADED_PAIRS="${LOADED_PAIRS:-0}"

# Honor MEMCACHED_PORT first, then PORT, fall back to 6500
MEMCACHED_PORT="${MEMCACHED_PORT:-${PORT:-11211}}"
MEMCACHED_TESTTIME="${MEMCACHED_TESTTIME:-15}"       # seconds
MEMCACHED_DATASIZE_RANGE="${MEMCACHED_DATASIZE_RANGE:-4-2048}" # bytes
MEMCACHED_DATASIZE_PATTERN="${MEMCACHED_DATASIZE_PATTERN:-R}"  
MEMCACHED_KEY_MAXIMUM="${MEMCACHED_KEY_MAXIMUM:-100000000}"
MEMCACHED_KEY_PATTERN="${MEMCACHED_KEY_PATTERN:-R:R}"
MEMCACHED_RATIO="${MEMCACHED_RATIO:-5:1}"           # SET:GET ratio
MEMCACHED_OUTPUT="${MEMCACHED_OUTPUT:-$OUTPUT/MEMCACHED.out}"
MEMCACHED_HISTOGRAM_FILE="${MEMCACHED_HISTOGRAM_FILE:-$OUTPUT/latency.out}"
SERVER_LOG="${SERVER_LOG:-$OUTPUT/server.log}"
SERVER_THREADS="${SERVER_THREADS:-4}"

# Optional prefixes (e.g., taskset/numactl) for pinning
MEMCACHED_PREFIX="${MEMCACHED_PREFIX:-}"
MEMTIER_PREFIX="${MEMTIER_PREFIX:-}"

flush() {
  [ "$FLUSH" = "1" ] && sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' || true
}

echo "==> starting MEMCACHED-server on $HOST:$MEMCACHED_PORT"

flush # Flush page cache

# start server in foreground, background the process; capture PID
echo "Printing server log to: $SERVER_LOG"
echo "==> MEMCACHED-server: ${MEMCACHED_PREFIX:+$MEMCACHED_PREFIX } memcached -p $MEMCACHED_PORT -u $USER -t $SERVER_THREADS -vv > $SERVER_LOG 2>&1 &"

vtune -collect memory-access -result-dir "$APPBENCH/vtune_projects/MEMCACHED_kdebug_clients_${CLIENTS}_threads_${THREADS}_loaded_pairs_$LOADED_PAIRS" \
    -knob analyze-mem-objects=true -finalization-mode=full \
    -search-dir="/usr/lib/debug/boot" \
    -- ${MEMCACHED_PREFIX:+$MEMCACHED_PREFIX } memcached -p "$MEMCACHED_PORT" \
        -u $USER -t $SERVER_THREADS -v > "$SERVER_LOG" 2>&1 &
SRV_PID=$!
echo "[SERVER PID]: $SRV_PID"

# wait for successful response from server (max ~10s)
for i in {1..50}; do
  printf "version\r\n" | nc -w 1 "$HOST" "$MEMCACHED_PORT" >/dev/null 2>&1 && break
  sleep 0.2
done

echo "==> starting memtier_benchmark ${MEMTIER_PREFIX:+$MEMTIER_PREFIX }memtier_benchmark --port "$MEMCACHED_PORT" --test-time="$MEMCACHED_TESTTIME" \
    --clients "$CLIENTS" --threads "$THREADS" --pipeline "$PIPELINE" \
    --random-data --data-size-range="$MEMCACHED_DATASIZE_RANGE" \
    --data-size-pattern="$MEMCACHED_DATASIZE_PATTERN" --key-maximum="$MEMCACHED_KEY_MAXIMUM" \
    --ratio="$MEMCACHED_RATIO" --hide-histogram \
    --out-file="$MEMCACHED_OUTPUT" --hdr-file-prefix="$MEMCACHED_HISTOGRAM_FILE" 2>&1 &"

${MEMTIER_PREFIX:+$MEMTIER_PREFIX }memtier_benchmark --port "$MEMCACHED_PORT" --test-time="$MEMCACHED_TESTTIME" \
    --protocol $PROTOCOL --clients "$CLIENTS" --threads "$THREADS" --pipeline "$PIPELINE" \
    --random-data --data-size-range="$MEMCACHED_DATASIZE_RANGE" \
    --data-size-pattern="$MEMCACHED_DATASIZE_PATTERN" --key-maximum="$MEMCACHED_KEY_MAXIMUM" \
    --ratio="$MEMCACHED_RATIO" --hide-histogram \
    --out-file="$MEMCACHED_OUTPUT" --hdr-file-prefix="$MEMCACHED_HISTOGRAM_FILE" 2>&1 &
MEMTIER_PID=$!
echo "[MEMTIER PID]: $MEMTIER_PID"

wait "$MEMTIER_PID" 2>/dev/null || true
kill "$SRV_PID" >/dev/null 2>&1 || true
wait "$SRV_PID" 2>/dev/null || true
echo "Done. Output: $MEMCACHED_OUTPUT"