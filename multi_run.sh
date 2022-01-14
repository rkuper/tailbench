#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -t|--benchmarks)
      BENCHMARKS="$2"
      shift
      shift
      ;;
    -m|--mem_configs)
      MEM_CONFIGS="$2"
      shift
      shift
      ;;
    -b|--bench_configs)
      BENCH_CONFIGS="$2"
      shift
      shift
      ;;
    -r|--runs)
      TOTAL_RUNS="$2"
      shift
      shift
      ;;
    -o|--output)
      OUTPUT_FILE="$2"
      shift; shift
      ;;
    -l|--keep_logs)
      KEEP_LOGS="$2"
      shift
      ;;
    -c|--context)
      CONTEXT="$2"
      shift
      ;;
    -e|--run_benchmarks)
      RUN_BENCHMARKS="$2"
      shift
      ;;
    -p|--process)
      PROCESS="$2"
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

BENCHMARKS=$([ "$BENCHMARKS" == "all" -o -z "${BENCHMARKS+x}" -o "$BENCHMARKS" == "" ] \
  && echo "img-dnn masstree moses silo specjbb sphinx xapian" || echo "$BENCHMARKS")
BENCHMARKS=($BENCHMARKS)
MEM_CONFIGS=$([ "$MEM_CONFIGS" == "all" -o -z "${MEM_CONFIGS+x}" -o "$MEM_CONFIGS" == "" ] \
  && echo "dram pmem both" || echo "$MEM_CONFIGS")
MEM_CONFIGS=($MEM_CONFIGS)
BENCH_CONFIGS=$([ "$BENCH_CONFIGS" == "all" -o -z "${BENCH_CONFIGS+x}" -o "$BENCH_CONFIGS" == "" ] \
  && echo "integrated networked" || echo "$BENCH_CONFIGS")
BENCH_CONFIGS=($BENCH_CONFIGS)
REGEX_NUM='^[0-9]+$'
TOTAL_RUNS=$([[ -v TOTAL_RUNS && $TOTAL_RUNS =~ $REGEX_NUM ]] && echo "$TOTAL_RUNS" || echo "1")
KEEP_LOGS=$([ -v KEEP_LOGS -o -z KEEP_LOGS ] && echo "true" || echo "false")
CONTEXT=$([ -v CONTEXT -o -z CONTEXT ] && echo "true" || echo "false")
RUN_BENCHMARKS=$([ -v RUN_BENCHMARKS -o -z RUN_BENCHMARKS ] && echo "true" || echo "false")
PROCESS=$([ -v PROCESS -o -z PROCESS ] && echo "true" || echo "false")
OUTPUT_FILE=$([ -v OUTPUT_FILE ] && echo "$OUTPUT_FILE" || echo "results.txt")
OUTPUT_PATH=`pwd`/results/${OUTPUT_FILE}
declare -a TYPES=("Queue" "Service" "Sojourn")
declare -a TAIL_METRICS=("50th" "75th" "90th" "95th" "99th" "99.5th" "Mean" "Max")



####################################
#            Benchmarks            #
####################################
if [ "$RUN_BENCHMARKS" == "true" ]
then
  for BENCHMARK in "${BENCHMARKS[@]}"
  do
    echo "##########################"
    echo "#        ${BENCHMARK}         #"
    echo "##########################"
    echo ""

    cd $BENCHMARK

    for MEM_CONFIG in "${MEM_CONFIGS[@]}"
    do

      for BENCH_CONFIG in "${BENCH_CONFIGS[@]}"
      do

        for RUN in $(eval echo {1..$TOTAL_RUNS})
        do

          echo "Run ${BENCH_CONFIG} ${RUN}:"
          echo "================="
          sudo pcm --external_program sudo pcm-memory --external_program \
            sudo numactl --cpunodebind=0-1 \
            --membind=$([ "$MEM_CONFIG" == "dram" ] && echo "0-1" || ([ "$MEM_CONFIG" == "pmem" ] && echo "2-3" || echo "0-3")) \
            ./run_${BENCH_CONFIG}.sh > ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_${RUN}_pcm.txt
          if [ -f "lats.bin" ];
          then
            python3 ../utilities/parselats.py lats.bin > ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_${RUN}_lats.txt
            mv ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_${RUN}_*.txt ../results/${BENCHMARK}
            rm lats.bin
          fi
          echo ""
        done

      done

    done

    cd ..
    echo ""; echo ""
  done
fi



####################################
#            Processing            #
####################################
if [ "$PROCESS" == "true" ]
then
 echo "Porcessing..."
  {
    cd results
    for BENCHMARK in "${BENCHMARKS[@]}"
    do

      echo "##########################"
      echo "#        ${BENCHMARK}         #"
      echo "##########################"
      echo ""
      cd $BENCHMARK

      for MEM_CONFIG in "${MEM_CONFIGS[@]}"
      do

        for BENCH_CONFIG in "${BENCH_CONFIGS[@]}"
        do

          echo "$MEM_CONFIG $BENCH_CONFIG"; echo "==============="

          # Metrics for tail latency reported by tailbench's harness
          ##########################################################
          for TYPE in "${TYPES[@]}"
          do
           if [ "$CONTEXT" == "false" ]
            then
              echo "$TYPE:"
            fi
            for TAIL_METRIC in "${TAIL_METRICS[@]}"
            do
              if [ -f "${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_1_lats.txt" ];
              then
                if [ "$CONTEXT" == "true" ]
                then
                  echo "[$TYPE] $TAIL_METRIC: " \
                    `awk '/\['"$TYPE"'\] '"$TAIL_METRIC"'/ {sum += $5; n++} END { if (n > 0) print sum / n; print "ms" }' \
                    ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_lats.txt`
                else
                  echo `awk '/\['"$TYPE"'\] '"$TAIL_METRIC"'/ {sum += $5; n++} END { if (n > 0) print sum / n }' \
                    ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_lats.txt`
                fi
              fi
            done
          echo ""
          done

          # PCM metrics
          #############
          MEM_CONFIG_SEARCH=$([ "$MEM_CONFIG" == "dram" ] && echo "DRAM" || ([ "$MEM_CONFIG" == "pmem" ] && echo "PMM" || echo "SYSTEM"))
          THROUGHPUT_INDEX=$([ "$MEM_CONFIG_SEARCH" == "SYSTEM" ] && echo "5" || echo "6")
          if [ -f "${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_1_pcm.txt" ];
          then
            if [ "$CONTEXT" == "true" ]
            then
              echo "[OVERALL] LLCRDMISSLAT: " \
                `awk '/LLCRDMISSLAT / {getline; getline; sum += $11; n++} END { if (n > 0) print sum / n; print "ns"}' \
                ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_pcm.txt`

              echo "[OVERALL] DIMM Energy: " \
                `awk '/LLCRDMISSLAT / {getline; getline; sum += $10; n++} END { if (n > 0) print sum / n; }' \
                ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_pcm.txt`

              echo "[OVERALL] ${MEM_CONFIG_SEARCH} Read Throughput: "\
                `awk '/'"$MEM_CONFIG_SEARCH"' Read Throughput/ {sum += $'"$THROUGHPUT_INDEX"'; n++} END \
                { if (n > 0) print sum / n; print "MB/s"}' \
                ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_pcm.txt`

              echo "[OVERALL] ${MEM_CONFIG_SEARCH} Write Throughput: "\
                `awk '/'"$MEM_CONFIG_SEARCH"' Write Throughput/ {sum += $'"$THROUGHPUT_INDEX"'; n++} END \
                { if (n > 0) print sum / n; print "MB/s"}' \
                ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_pcm.txt`

            else
              echo "Overall:"
              echo `awk '/LLCRDMISSLAT / {getline; getline; sum += $11; n++} END { if (n > 0) print sum / n; }' \
                ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_pcm.txt`

              echo `awk '/DIMM energy / {getline; getline; sum += $10; n++} END { if (n > 0) print sum / n; }' \
                ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_pcm.txt`

              echo `awk '/'"$MEM_CONFIG_SEARCH"' Read Throughput/ {sum += $'"$THROUGHPUT_INDEX"'; n++} END \
                { if (n > 0) print sum / n; }' \
                ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_pcm.txt`

              echo `awk '/'"$MEM_CONFIG_SEARCH"' Write Throughput/ {sum += $'"$THROUGHPUT_INDEX"'; n++} END \
                { if (n > 0) print sum / n; }' \
                ${BENCHMARK}_${MEM_CONFIG}_${BENCH_CONFIG}_*_pcm.txt`
            fi
          fi
          echo ""

        done
        echo ""; echo "";

      done
      cd ..

    done
    if [ "$KEEP_LOGS" == "false" ]
    then
      rm "$BENCHMARK"_*_lats_*.txt
    fi
    cd ..
  } > ${OUTPUT_PATH}
fi
