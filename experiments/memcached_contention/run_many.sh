#!/usr/bin/env bash
set -euo pipefail

# How many client-server pairs
# You can tweak this or drive from CLI args.
PAIRS_CORES=(
  "0-7,8-15"   # pair 0: server core 0, client core 1-2
#   "4,5-6"   # pair 1: server core 3, client core 4-5
#   "7,8-9"   # pair 2: server core 6, client core 7-8
#   "10,11-12"   # pair 3: server core 9, client core 10-11
#   "13,14-15"   # pair 4: server core 12, client core 13-14
#   "33,34-35"   # pair 5: server core 32, client core 33-34
#   "36,37-38"   # pair 6: server core 35, client core 36-37
#   "39,40-41"   # pair 7: server core 38, client core 39-40
#   "42,43-44"   # pair 8: server core 41, client core 42-43
#   "45,46-47"   # pair 9: server core 44, client core 45-46
)

declare -a client_arr=("50")
declare -a thread_arr=("8")
declare -a pipeline_arr=("1")
declare -a server_threads_arr=("8")
# declare -a client_arr=("50")
# declare -a thread_arr=("4")
# declare -a pipeline_arr=("1")

BASE_PORT=11211

MAX_LOADED_PAIRS=$(( ${#PAIRS_CORES[@]} - 1 ))

for CLIENTS in "${client_arr[@]}"; do
    for THREADS in "${thread_arr[@]}"; do
        for PIPELINE in "${pipeline_arr[@]}"; do
            for SERVER_THREADS in "${server_threads_arr[@]}"; do
                for LOAD_PAIRS in $(seq 0 "$MAX_LOADED_PAIRS"); do
                    OUT_BASE="${PWD}/test_memory_bound/loaded_pairs_${LOAD_PAIRS}"
                    mkdir -p "$OUT_BASE"
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
                        MEMCACHED_OUTPUT="$RUN_FOLDER/memcached.out"
                        MEMCACHED_HISTOGRAM_FILE="$RUN_FOLDER/latency.out"

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
                            MEMCACHED_PORT="$port" \
                            SERVER_LOG="$SERVER_LOG" \
                            SERVER_THREADS="$SERVER_THREADS" \
                            MEMCACHED_OUTPUT="$MEMCACHED_OUTPUT" \
                            MEMCACHED_HISTOGRAM_FILE="$MEMCACHED_HISTOGRAM_FILE" \
                            MEMCACHED_PREFIX="taskset -c $srv_core" \
                            MEMTIER_PREFIX="/usr/bin/time -v taskset -c $cli_core" \
                            ./memcached_pair.sh > "$RUN_FOLDER/memcached_pair" 2>&1 &
                        else
                            FLUSH=1 \
                            MEMCACHED_PORT="$port" \
                            SERVER_LOG="$SERVER_LOG" \
                            SERVER_THREADS="$SERVER_THREADS" \
                            MEMCACHED_OUTPUT="$MEMCACHED_OUTPUT" \
                            MEMCACHED_HISTOGRAM_FILE="$MEMCACHED_HISTOGRAM_FILE" \
                            MEMCACHED_PREFIX="taskset -c $srv_core" \
                            MEMTIER_PREFIX="/usr/bin/time -v taskset -c $cli_core" \
                            ./memcached_pair_silence.sh > "$RUN_FOLDER/memcached_pair_silence" 2>&1 &
                        fi
                    done
                    wait
                done
            done
        done
    done
done

echo "All pairs completed."
