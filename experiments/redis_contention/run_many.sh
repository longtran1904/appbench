#!/usr/bin/env bash
set -euo pipefail

# How many client-server pairs
# You can tweak this or drive from CLI args.
# PAIRS_CORES=(
#   "1,2-3"   # pair 0: server core 0, client core 1-2
#   "4,5-6"   # pair 1: server core 3, client core 4-5
#   "7,8-9"   # pair 2: server core 6, client core 7-8
#   "10,11-12"   # pair 3: server core 9, client core 10-11
#   "13,14-15"   # pair 4: server core 12, client core 13-14
#   "33,34-35"   # pair 5: server core 32, client core 33-34
#   "36,37-38"   # pair 6: server core 35, client core 36-37
#   "39,40-41"   # pair 7: server core 38, client core 39-40
#   "42,43-44"   # pair 8: server core 41, client core 42-43
#   "45,46-47"   # pair 9: server core 44, client core 45-46
# )

PAIRS_CORES=(
    "1,16"
    "2,17"
    "3,18"
    "4,19"
    "5,20"
    "6,21"
    "7,22"
    "8,23"
    "9,24"
    "10,25"
    "11,26"
    "12,27"
    "13,28"
    "14,29"
    "15,30"
    "32,48"
    "33,49"
    "34,50"
    "35,51"
    "36,52"
    "37,53"
    "38,54"
    "39,55"
    "40,56"
    "41,57"
    "42,58"
    "43,59"
    "44,60"
    "45,61"
    "46,62"
    "47,63"
)

declare -a client_arr=("1")
declare -a thread_arr=("4")
declare -a pipeline_arr=("1")
# declare -a client_arr=("50")
# declare -a thread_arr=("4")
# declare -a pipeline_arr=("1")

BASE_PORT=6500

MAX_LOADED_PAIRS=$(( ${#PAIRS_CORES[@]} - 1 ))

for CLIENTS in "${client_arr[@]}"; do
    for THREADS in "${thread_arr[@]}"; do
        for PIPELINE in "${pipeline_arr[@]}"; do
            for LOAD_PAIRS in $(seq 0 "$MAX_LOADED_PAIRS"); do
                OUT_BASE="${PWD}/redis_contention_3/loaded_pairs_${LOAD_PAIRS}"
                mkdir -p "$OUT_BASE"
                READY_FLAG="$OUT_BASE/ready.txt"
                rm -f "$READY_FLAG" 2>/dev/null || true
                for i in "${!PAIRS_CORES[@]}"; do
                    if (( i != 0 && i > LOAD_PAIRS )); then
                        # This load pair is not active in this run
                        continue
                    fi

                    echo "---- RUN: clients=$CLIENTS threads=$THREADS pipeline=$PIPELINE ----"

                    OUTPUT="$OUT_BASE/pair_$i"
                    mkdir -p "$OUTPUT"

                    RUN_FOLDER="$OUTPUT/clients_${CLIENTS}_threads_${THREADS}_pipeline_${PIPELINE}"
                    mkdir -p "$RUN_FOLDER"
                    SERVER_LOG="$RUN_FOLDER/server.log"
                    REDIS_OUTPUT="$RUN_FOLDER/redis.out"
                    REDIS_HISTOGRAM_FILE="$RUN_FOLDER/latency.out"

                    cores="${PAIRS_CORES[$i]}"
                    srv_core="${cores%%,*}"
                    cli_core="${cores##*,}"
                    port=$((BASE_PORT + i))

                    echo "Launching pair $i on port $port (server core $srv_core, client core $cli_core)"

                    # For multi-pair runs, usually you don't want to drop caches each time

                    if [[ "$i" == 0 ]]; then
                    # First pair flushes caches
                        FLUSH=1 \
                        LOADED_PAIRS="$LOAD_PAIRS" \
                        CLIENTS="$CLIENTS" THREADS="$THREADS" PIPELINE="$PIPELINE" \
                        READY_FLAG="$READY_FLAG" \
                        REDIS_PORT="$port" PORT="$port" \
                        SERVER_LOG="$SERVER_LOG" \
                        REDIS_OUTPUT="$REDIS_OUTPUT" \
                        REDIS_HISTOGRAM_FILE="$REDIS_HISTOGRAM_FILE" \
                        REDIS_PREFIX="taskset -c $srv_core" \
                        MEMTIER_PREFIX="/usr/bin/time -v taskset -c $cli_core" \
                        ./redis_pair.sh > "$RUN_FOLDER/redis_pair" 2>&1 &
                    else
                        FLUSH=1 \
                        REDIS_PORT="$port" PORT="$port" \
                        READY_FLAG="$READY_FLAG" \
                        SERVER_LOG="$SERVER_LOG" \
                        REDIS_OUTPUT="$REDIS_OUTPUT" \
                        REDIS_HISTOGRAM_FILE="$REDIS_HISTOGRAM_FILE" \
                        REDIS_PREFIX="taskset -c $srv_core" \
                        MEMTIER_PREFIX="/usr/bin/time -v taskset -c $cli_core" \
                        ./redis_pair_silence.sh > "$RUN_FOLDER/redis_pair" 2>&1 &
                    fi
                done
                wait
                sleep 5  # wait a bit before starting next run
            done
        done
    done
done

echo "All pairs completed."
