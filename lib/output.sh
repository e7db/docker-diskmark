#!/bin/bash
# output.sh - Output formatting functions
# Provides: output_* functions for all output formats

escape_json() {
  echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g'
}

output_config_human() {
  echo -e "$(color $BOLD $WHITE)Configuration:$(color $RESET)
- Target: $TARGET
  - $DRIVELABEL: $DRIVEINFO
  - Filesystem: $FILESYSTEMTYPE ($FILESYSTEMPARTITION, $FILESYSTEMSIZE)
- Profile: $PROFILE
  - I/O: $IO
  - Data: $DATA
  - Size: $SIZE
  - Warmup: $WARMUP$([ "$WARMUP" -eq 1 ] && echo " (block: ${BLOCK_MB}M)")
  - $LIMIT
"
}

output_running_message() {
  if [[ -z "$FORMAT" ]]; then
    echo -e "The benchmark is $(color $BOLD $WHITE)running$(color $RESET), please wait..."
  fi
}

output_dry_run_success() {
  echo -e "$SYM_SUCCESS Dry run $(color $BOLD $GREEN)completed$(color $RESET). Configuration is valid."
}

output_results_human() {
  local total=${#RESULTS_NAME[@]}
  local has_skipped=0
  for ((j = 0; j < total; j++)); do
    [[ "${RESULTS_STATUS[$j]}" == "skipped" ]] && has_skipped=1 && break
  done
  if [ $has_skipped -eq 1 ]; then
    echo -e "\n$SYM_SUCCESS The benchmark is $(color $BOLD $GREEN)finished$(color $RESET) with $(color $BOLD $YELLOW)warnings$(color $RESET):"
    for job in "${SKIPPED_JOBS[@]}"; do
      echo -e "  - $job"
    done
  else
    echo -e "\n$SYM_SUCCESS The benchmark is $(color $BOLD $GREEN)finished$(color $RESET)."
  fi
}

output_results_json() {
  local total=${#RESULTS_NAME[@]}
  echo "{"
  echo "  \"configuration\": {"
  echo "    \"target\": \"$(escape_json "$TARGET")\","
  echo "    \"drive\": {"
  echo "      \"label\": \"$(escape_json "$DRIVELABEL")\","
  echo "      \"info\": \"$(escape_json "$DRIVEINFO")\""
  echo "    },"
  echo "    \"filesystem\": {"
  echo "      \"type\": \"$(escape_json "$FILESYSTEMTYPE")\","
  echo "      \"partition\": \"$(escape_json "$FILESYSTEMPARTITION")\","
  echo "      \"size\": \"$(escape_json "$FILESYSTEMSIZE")\""
  echo "    },"
  echo "    \"profile\": \"$(escape_json "$PROFILE")\","
  echo "    \"io\": \"$(escape_json "$IO")\","
  echo "    \"data\": \"$(escape_json "$DATA")\","
  echo "    \"size\": \"$SIZE\","
  echo "    \"warmup\": $WARMUP,"
  if [[ -n "$LOOPS" ]]; then
    echo "    \"loops\": $LOOPS"
  else
    echo "    \"runtime\": \"$RUNTIME\""
  fi
  echo "  },"
  echo "  \"results\": ["
  for ((j = 0; j < total; j++)); do
    echo -n "    {\"name\": \"$(escape_json "${RESULTS_NAME[$j]}")\", \"status\": \"${RESULTS_STATUS[$j]}\""
    if [[ "${RESULTS_STATUS[$j]}" != "skipped" ]]; then
      echo -n ", \"read\": {\"bandwidth_mb\": ${RESULTS_READ_BW[$j]}, \"iops\": ${RESULTS_READ_IOPS[$j]}, \"latency_ms\": ${RESULTS_READ_LAT[$j]}}, \"write\": {\"bandwidth_mb\": ${RESULTS_WRITE_BW[$j]}, \"iops\": ${RESULTS_WRITE_IOPS[$j]}, \"latency_ms\": ${RESULTS_WRITE_LAT[$j]}}"
    fi
    echo -n "}"
    [[ $j -lt $((total - 1)) ]] && echo "," || echo
  done
  echo "  ]"
  echo "}"
}

output_results_yaml() {
  local total=${#RESULTS_NAME[@]}
  echo "configuration:"
  echo "  target: \"$(escape_json "$TARGET")\""
  echo "  drive:"
  echo "    label: \"$(escape_json "$DRIVELABEL")\""
  echo "    info: \"$(escape_json "$DRIVEINFO")\""
  echo "  filesystem:"
  echo "    type: \"$(escape_json "$FILESYSTEMTYPE")\""
  echo "    partition: \"$(escape_json "$FILESYSTEMPARTITION")\""
  echo "    size: \"$(escape_json "$FILESYSTEMSIZE")\""
  echo "  profile: \"$(escape_json "$PROFILE")\""
  echo "  io: \"$(escape_json "$IO")\""
  echo "  data: \"$(escape_json "$DATA")\""
  echo "  size: \"$SIZE\""
  echo "  warmup: $WARMUP"
  if [[ -n "$LOOPS" ]]; then
    echo "  loops: $LOOPS"
  else
    echo "  runtime: \"$RUNTIME\""
  fi
  echo "results:"
  for ((j = 0; j < total; j++)); do
    echo "  - name: \"$(escape_json "${RESULTS_NAME[$j]}")\""
    echo "    status: \"${RESULTS_STATUS[$j]}\""
    if [[ "${RESULTS_STATUS[$j]}" != "skipped" ]]; then
      echo "    read:"
      echo "      bandwidth_mb: ${RESULTS_READ_BW[$j]}"
      echo "      iops: ${RESULTS_READ_IOPS[$j]}"
      echo "      latency_ms: ${RESULTS_READ_LAT[$j]}"
      echo "    write:"
      echo "      bandwidth_mb: ${RESULTS_WRITE_BW[$j]}"
      echo "      iops: ${RESULTS_WRITE_IOPS[$j]}"
      echo "      latency_ms: ${RESULTS_WRITE_LAT[$j]}"
    fi
  done
}

output_results_xml() {
  local total=${#RESULTS_NAME[@]}
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo "<benchmark>"
  echo "  <configuration>"
  echo "    <target>$TARGET</target>"
  echo "    <drive label=\"$DRIVELABEL\">$DRIVEINFO</drive>"
  echo "    <filesystem type=\"$FILESYSTEMTYPE\" partition=\"$FILESYSTEMPARTITION\" size=\"$FILESYSTEMSIZE\" />"
  echo "    <profile>$PROFILE</profile>"
  echo "    <io>$IO</io>"
  echo "    <data>$DATA</data>"
  echo "    <size>$SIZE</size>"
  echo "    <warmup>$WARMUP</warmup>"
  if [[ -n "$LOOPS" ]]; then
    echo "    <loops>$LOOPS</loops>"
  else
    echo "    <runtime>$RUNTIME</runtime>"
  fi
  echo "  </configuration>"
  echo "  <results>"
  for ((j = 0; j < total; j++)); do
    echo "    <job name=\"${RESULTS_NAME[$j]}\" status=\"${RESULTS_STATUS[$j]}\">"
    if [[ "${RESULTS_STATUS[$j]}" != "skipped" ]]; then
      echo "      <read bandwidth_mb=\"${RESULTS_READ_BW[$j]}\" iops=\"${RESULTS_READ_IOPS[$j]}\" latency_ms=\"${RESULTS_READ_LAT[$j]}\" />"
      echo "      <write bandwidth_mb=\"${RESULTS_WRITE_BW[$j]}\" iops=\"${RESULTS_WRITE_IOPS[$j]}\" latency_ms=\"${RESULTS_WRITE_LAT[$j]}\" />"
    fi
    echo "    </job>"
  done
  echo "  </results>"
  echo "</benchmark>"
}

output_results() {
  case "$FORMAT" in
    "") output_results_human ;;
    json) output_results_json ;;
    yaml) output_results_yaml ;;
    xml) output_results_xml ;;
  esac
}
