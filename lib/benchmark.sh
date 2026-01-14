#!/bin/bash
# benchmark.sh - Benchmark execution functions
# Provides: warmup, fio_benchmark, run_benchmarks

prepare_benchmark_params() {
  SIZE="${SIZE:-1G}"
  BYTESIZE=$(toBytes $SIZE)
  WARMUP="${WARMUP:-1}"

  if [ -z "$WARMUP_SIZE" ]; then
    case "$PROFILE" in
      *nvme*) WARMUP_SIZE="64M" ;;
      *) WARMUP_SIZE="8M" ;;
    esac
  fi

  validate_size_string "$WARMUP_SIZE" "WARMUP_SIZE"
  WARMUP_BLOCK_BYTES=$(toBytes $WARMUP_SIZE)
  if [ -z "$WARMUP_BLOCK_BYTES" ] || [ "$WARMUP_BLOCK_BYTES" -le 0 ]; then
    WARMUP_BLOCK_BYTES=$(toBytes 8M)
    WARMUP_SIZE="8M"
  fi
  BLOCK_MB=$((WARMUP_BLOCK_BYTES / 1024 / 1024))
  [ "$BLOCK_MB" -lt 1 ] && BLOCK_MB=1
  [ "$BLOCK_MB" -gt 1024 ] && BLOCK_MB=1024

  if [[ -n "$LOOPS" ]] && [[ -n "$RUNTIME" ]]; then
    LIMIT="Loops: $LOOPS (max $RUNTIME each)"
    LIMIT_OPTION="--loops=$LOOPS --runtime=$RUNTIME"
  elif [[ -n "$LOOPS" ]]; then
    LIMIT="Loops: $LOOPS"
    LIMIT_OPTION="--loops=$LOOPS"
  else
    RUNTIME="${RUNTIME:-5s}"
    LIMIT="Runtime: $RUNTIME"
    LIMIT_OPTION="--time_based --runtime=$RUNTIME"
  fi
}

run_warmup() {
  if [ $WARMUP -eq 1 ]; then
    if [ $WRITEZERO -eq 1 ]; then
      FILESOURCE=/dev/zero
    else
      FILESOURCE=/dev/urandom
    fi
    TOTAL_MB=$((BYTESIZE / 1024 / 1024))
    if [ "$TOTAL_MB" -eq 0 ]; then
      dd if="$FILESOURCE" of="$TARGET/.diskmark.tmp" bs="$BYTESIZE" count=1 oflag=direct status=none
    else
      CHUNKS=$((TOTAL_MB / BLOCK_MB))
      REMAINDER_MB=$((TOTAL_MB % BLOCK_MB))
      if [ $CHUNKS -gt 0 ]; then
        dd if="$FILESOURCE" of="$TARGET/.diskmark.tmp" bs=${BLOCK_MB}M count=$CHUNKS oflag=direct status=none
      fi
      if [ $REMAINDER_MB -gt 0 ]; then
        dd if="$FILESOURCE" of="$TARGET/.diskmark.tmp" bs=1M count=$REMAINDER_MB oflag=direct conv=notrunc seek=$((CHUNKS * BLOCK_MB)) status=none
      fi
    fi
  fi
}

fio_benchmark() {
  fio --filename="$TARGET/.diskmark.tmp" \
    --stonewall --ioengine=libaio --direct=$DIRECT --zero_buffers=$WRITEZERO \
    $LIMIT_OPTION --size="$1" \
    --name="$2" --blocksize="$3" --iodepth="$4" --numjobs="$5" --readwrite="$6" \
    --output-format=json >"$TARGET/.diskmark.json"
}

parse_result_raw() {
  local bandwidth=$(cat "$TARGET/.diskmark.json" | grep -A"$2" '"name" : "'"$1"'"' | grep "$3" | sed 's/        "'"$3"'" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.6f", SUM / 1024 / 1024 }')
  local throughput=$(cat "$TARGET/.diskmark.json" | grep -A"$2" '"name" : "'"$1"'"' | grep "$4" | sed 's/        "'"$4"'" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.6f", SUM }')
  echo "$bandwidth $throughput"
}

parse_latency() {
  local job_name="$1"
  local operation="$2"
  local lat_ns=$(cat "$TARGET/.diskmark.json" | \
    grep -A200 '"name" : "'"$job_name"'"' | \
    grep -A50 "\"$operation\" :" | \
    grep -A5 '"clat_ns"' | \
    grep '"mean"' | head -1 | sed 's/.*: //g' | sed 's:,::g')
  if [[ -n "$lat_ns" ]]; then
    echo "$lat_ns" | awk '{printf "%.6f", $1 / 1000000}'
  else
    echo "0"
  fi
}

format_latency() {
  local lat_ms="$1"
  if [[ -z "$lat_ms" ]] || [[ "$lat_ms" == "0" ]]; then
    echo "0.00ms"
  elif awk "BEGIN {exit !($lat_ms >= 0.01)}"; then
    printf "%.2fms" "$lat_ms"
  elif awk "BEGIN {exit !($lat_ms >= 0.001)}"; then
    printf "%.3fms" "$lat_ms"
  else
    local lat_ns=$(awk "BEGIN {printf \"%.0f\", $lat_ms * 1000000}")
    echo "${lat_ns}ns"
  fi
}

clear_progress() {
  if [[ -z "$FORMAT" ]]; then
    printf "\r\033[K"
  fi
}

show_progress() {
  if [[ -z "$FORMAT" ]]; then
    if [[ "$2" == *"read"* ]]; then
      printf "\n[%d/%d] %s..." "$1" "$TOTAL_JOBS" "$2"
    else
      printf "\r[%d/%d] %s..." "$1" "$TOTAL_JOBS" "$2"
    fi
  fi
}

run_all_benchmarks() {
  TOTAL_JOBS=${#NAME[@]}
  RESULTS_NAME=()
  RESULTS_STATUS=()
  RESULTS_READ_BW=()
  RESULTS_READ_IOPS=()
  RESULTS_READ_LAT=()
  RESULTS_WRITE_BW=()
  RESULTS_WRITE_IOPS=()
  RESULTS_WRITE_LAT=()
  SKIPPED_JOBS=()

  for ((i = 0; i < ${#NAME[@]}; i++)); do
    JOB_NUM=$((i + 1))
    DIVIDER=${SIZEDIVIDER[$i]:-1}
    if [ "$DIVIDER" -le 0 ]; then
      TESTSIZE=$BYTESIZE
    else
      TESTSIZE=$((BYTESIZE / DIVIDER))
    fi
    BLOCKSIZE_BYTES=$(toBytes "${BLOCKSIZE[$i]}")

    if [ "$TESTSIZE" -lt "$BLOCKSIZE_BYTES" ]; then
      SKIPPED_JOBS+=("${NAME[$i]} (size $(fromBytes $TESTSIZE) < block size ${BLOCKSIZE[$i]})")
      RESULTS_NAME+=("${NAME[$i]}")
      RESULTS_STATUS+=("skipped")
      RESULTS_READ_BW+=(0)
      RESULTS_READ_IOPS+=(0)
      RESULTS_READ_LAT+=(0)
      RESULTS_WRITE_BW+=(0)
      RESULTS_WRITE_IOPS+=(0)
      RESULTS_WRITE_LAT+=(0)
      if [[ -z "$FORMAT" ]]; then
        echo
        echo -e "${JOBCOLOR[$i]}${LABEL[$i]}:$(color $RESET) Skipped"
      fi
      continue
    fi

    show_progress "$JOB_NUM" "${NAME[$i]} read"
    fio_benchmark "$TESTSIZE" "${NAME[$i]}Read" "${BLOCKSIZE[$i]}" "${IODEPTH[$i]}" "${NUMJOBS[$i]}" "${READWRITE[$i]}read"
    READ_RAW=$(parse_result_raw "${NAME[$i]}Read" 15 bw_bytes iops)
    READ_BW=$(echo "$READ_RAW" | awk '{print $1}')
    READ_IOPS=$(echo "$READ_RAW" | awk '{print $2}')
    READ_LAT=$(parse_latency "${NAME[$i]}Read" "read")

    show_progress "$JOB_NUM" "${NAME[$i]} write"
    fio_benchmark "$TESTSIZE" "${NAME[$i]}Write" "${BLOCKSIZE[$i]}" "${IODEPTH[$i]}" "${NUMJOBS[$i]}" "${READWRITE[$i]}write"
    WRITE_RAW=$(parse_result_raw "${NAME[$i]}Write" 80 bw_bytes iops)
    WRITE_BW=$(echo "$WRITE_RAW" | awk '{print $1}')
    WRITE_IOPS=$(echo "$WRITE_RAW" | awk '{print $2}')
    WRITE_LAT=$(parse_latency "${NAME[$i]}Write" "write")

    if [[ -z "$FORMAT" ]]; then
      clear_progress
      echo -e "${JOBCOLOR[$i]}${LABEL[$i]}:$(color $RESET)"
      printf "<= Read:  %.0f MB/s, %.0f IO/s, %s\n" "$READ_BW" "$READ_IOPS" "$(format_latency $READ_LAT)"
      printf "=> Write: %.0f MB/s, %.0f IO/s, %s\n" "$WRITE_BW" "$WRITE_IOPS" "$(format_latency $WRITE_LAT)"
    fi

    RESULTS_NAME+=("${NAME[$i]}")
    RESULTS_STATUS+=("success")
    RESULTS_READ_BW+=($READ_BW)
    RESULTS_READ_IOPS+=($READ_IOPS)
    RESULTS_READ_LAT+=($READ_LAT)
    RESULTS_WRITE_BW+=($WRITE_BW)
    RESULTS_WRITE_IOPS+=($WRITE_IOPS)
    RESULTS_WRITE_LAT+=($WRITE_LAT)
  done
}
