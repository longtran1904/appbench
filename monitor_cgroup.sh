#!/bin/bash
APP=$1
CGROUP_PATH="/sys/fs/cgroup/lht21-group-$APP"
APPLOG="${APPBENCH}/${APP}_log"

echo "Monitoring cgroup memory stats for: $CGROUP_PATH"
echo "Press Ctrl+C to stop."
echo ""

rm -r $APPLOG
mkdir $APPLOG
while true; do
    clear
    echo "Timestamp: $(date)"
    echo "---------------------------------------------"
    echo "cpuset.cpus"
    cat $CGROUP_PATH/cpuset.cpus
    echo "cgroup.procs"
    cat $CGROUP_PATH/cgroup.procs

    echo "memory.current     : $(cat $CGROUP_PATH/memory.current) bytes" | tee -a "$APPLOG/memory.current.log"
    echo "memory.max         : $(cat $CGROUP_PATH/memory.max)" | tee -a "$APPLOG/memory.max.log"
    echo "memory.high        : $(cat $CGROUP_PATH/memory.high)" | tee -a "$APPLOG/memory.high.log"
    echo "memory.swap        : $(cat $CGROUP_PATH/memory.swap.current) bytes" | tee -a "$APPLOG/memory.swap.log"

    PRESSURE_FILE="$CGROUP_PATH/memory.pressure"
    SOME_LINE=$(grep "^some" "$PRESSURE_FILE")
    FULL_LINE=$(grep "^full" "$PRESSURE_FILE")
    echo ""
    echo "memory.pressure:"
    echo "$SOME_LINE" | tee -a "$APPLOG/memory.pressure.some.log"
    echo "$FULL_LINE" | tee -a "$APPLOG/memory.pressure.full.log"

    echo ""
    echo "memory.events:"
    cat $CGROUP_PATH/memory.events

    sleep 1
done

