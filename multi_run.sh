#!/bin/bash

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -b|--benchmarks)
      BENCHMARKS="$2"
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
      KEEP_LOGS="$2"
      shift
      ;;
    -e|--run_benchmarks)
      KEEP_LOGS="$2"
      shift
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

BENCHMARKS=$([ "$BENCHMARKS" == "all" -o -z "${BENCHMARKS+x}" -o "$BENCHMARKS" == "" ] \
  && echo "img-dnn masstree moses silo sphinx specjbb xapian" || echo "$BENCHMARKS")
BENCHMARKS=($BENCHMARKS)
REGEX_NUM='^[0-9]+$'
TOTAL_RUNS=$([[ -v TOTAL_RUNS && $TOTAL_RUNS =~ $REGEX_NUM ]] && echo "$TOTAL_RUNS" || echo "1")
KEEP_LOGS=$([ -v KEEP_LOGS -o -z KEEP_LOGS ] && echo "true" || echo "false")
CONTEXT=$([ -v CONTEXT -o -z CONTEXT ] && echo "true" || echo "false")
RUN_BENCHMARKS=$([ -v RUN_BENCHMARKS -o -z RUN_BENCHMARKS ] && echo "true" || echo "false")
OUTPUT_FILE=$([ -v OUTPUT_FILE ] && echo "$OUTPUT_FILE" || echo "results.txt")
declare -a CONFIGS=("integrated" "networked")
declare -a TYPES=("Queue" "Service" "Sojourn")
declare -a METRICS=("50th" "75th" "90th" "95th" "99th" "99.5th" "Mean" "Max")



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
    for CONFIG in "${CONFIGS[@]}"
    do
      case $CONFIG in
        integrated)
          for RUN in $(eval echo {1..$TOTAL_RUNS})
          do
            echo "Run Integrated ${RUN}:"
            echo "================="
            sudo ./run.sh
            if [ -f "lats.bin" ];
            then
              python3 ../utilities/parselats.py lats.bin > ${BENCHMARK}_${CONFIG}_${RUN}_lats.txt
              mv ${BENCHMARK}_${CONFIG}_${RUN}_lats.txt ../lats
              rm lats.bin
            fi
            echo ""
          done
          ;;
        networked)
          for RUN in $(eval echo {1..$TOTAL_RUNS})
          do
            echo "Run Networked ${RUN}:"
            echo "================"
            sudo ./run_networked.sh
            if [ -f "lats.bin" ];
            then
              python3 ../utilities/parselats.py lats.bin > ${BENCHMARK}_${CONFIG}_${RUN}_lats.txt
              mv ${BENCHMARK}_${CONFIG}_${RUN}_lats.txt ../lats
              rm lats.bin
            fi
            echo ""
          done
          ;;
        *)
          break
          ;;
      esac
    done
    cd ..
    echo ""; echo ""
  done
fi



####################################
#            Processing            #
####################################
echo "Porcessing..."
{
  cd lats
  for BENCHMARK in "${BENCHMARKS[@]}"
  do
    echo "##########################"
    echo "#        ${BENCHMARK}         #"
    echo "##########################"
    echo ""
    for CONFIG in "${CONFIGS[@]}"
    do
      echo "$CONFIG"; echo "=========="
      for TYPE in "${TYPES[@]}"
      do
        for METRIC in "${METRICS[@]}"
        do
          if [ -f "${BENCHMARK}_${CONFIG}_1_lats.txt" ];
          then
						if [ "$CONTEXT" == "true" ]
						then
            	echo "[$TYPE] $METRIC: " \
              	`awk '/\['"$TYPE"'\] '"$METRIC"'/ {sum += $5; n++} END { if (n > 0) print sum / n; print "ms" }' \
              	${BENCHMARK}_${CONFIG}_*_lats.txt`
						else
            	echo `awk '/\['"$TYPE"'\] '"$METRIC"'/ {sum += $5; n++} END { if (n > 0) print sum / n }' \
              	${BENCHMARK}_${CONFIG}_*_lats.txt`
          	fi
					fi
        done
      echo ""
      done
    done
    echo ""; echo ""; echo ""
  done
  if [ "$KEEP_LOGS" == "false" ]
  then
    rm "$BENCHMARK"_*_lats_*.txt
  fi
  cd ..
} > results.txt
