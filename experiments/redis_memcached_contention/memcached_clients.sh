OUTPUT="${OUTPUT:-${OUTPUTDIR:-$PWD}/memcached}"

HOST="${HOST:-127.0.0.1}"
PROTOCOL="${PROTOCOL:-memcache_binary}"
MEMCACHED_PORT="${PORT:-11211}"
MEMCACHED_TESTTIME="${MEMCACHED_TESTTIME:-60}"       # seconds
MEMCACHED_DATASIZE_RANGE="${MEMCACHED_DATASIZE_RANGE:-4-2048}" # bytes
MEMCACHED_DATASIZE_PATTERN="${MEMCACHED_DATASIZE_PATTERN:-R}"  
MEMCACHED_KEY_MAXIMUM="${MEMCACHED_KEY_MAXIMUM:-100000000}"
MEMCACHED_KEY_PATTERN="${MEMCACHED_KEY_PATTERN:-R:R}"
MEMCACHED_RATIO="${MEMCACHED_RATIO:-1:1}"           # read:set ratio
MEMCACHED_OUTPUT="${MEMCACHED_OUTPUT:-$OUTPUT/MEMCACHED.out}"
MEMCACHED_HISTOGRAM_FILE="${MEMCACHED_HISTOGRAM_FILE:-$OUTPUT/latency.out}"

FLUSH="${FLUSH:-1}"               # set FLUSH=1 to drop caches (needs sudo)

echo "OUTPUT: $OUTPUT"

mkdir -p "$OUTPUT"

trap "echo 'Cleaning up...'; kill 0" INT TERM EXIT

flush() {
  [ "$FLUSH" = "1" ] && sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' || true
}

echo "==> starting redis-server on $HOST:$PORT"
flush

memtier_benchmark --host $HOST --port $MEMCACHED_PORT \
  --protocol $PROTOCOL --test-time=$MEMCACHED_TESTTIME \
  --random-data --data-size-range=$MEMCACHED_DATASIZE_RANGE \
  --data-size-pattern=$MEMCACHED_DATASIZE_PATTERN --key-maximum=$MEMCACHED_KEY_MAXIMUM \
  --ratio=$MEMCACHED_RATIO --hide-histogram \
  --out-file=$MEMCACHED_OUTPUT --hdr-file-prefix=$MEMCACHED_HISTOGRAM_FILE 