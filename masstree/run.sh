#!/bin/bash

if [[ -z "${NTHREADS}" ]]; then NTHREADS=1; fi

QPS=1000
MAXREQS=3000
WARMUPREQS=14000

TBENCH_QPS=${QPS} TBENCH_MAXREQS=${MAXREQS} TBENCH_WARMUPREQS=${WARMUPREQS} \
    TBENCH_MINSLEEPNS=10000 chrt -r 99 ./mttest_integrated -j${NTHREADS} \
    mycsba masstree &

echo $! > integrated.pid

# performance monitoring
../utilities/pidstat.sh $(cat integrated.pid) &
echo $! > pidstat.pid
../utilities/ps.sh $(cat integrated.pid) &
echo $! > ps.pid
../utilities/vmstat.sh &
echo $! > vmstat.pid

wait $(cat integrated.pid)
rm integrated.pid pidstat.pid ps.pid vmstat.pid
kill $(jobs -p)
pkill -9 -x vmstat
