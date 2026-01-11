#!/bin/bash

set -e

is_semver() {
  [[ "$1" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]
}

UPDATE_CHECK="${UPDATE_CHECK:-1}"
if [[ ! "$UPDATE_CHECK" =~ ^[01]$ ]]; then
  echo "Error: UPDATE_CHECK must be either 0 or 1." >&2
  exit 1
fi

FORMAT="${FORMAT:-}"
if [[ -n "$FORMAT" && ! "$FORMAT" =~ ^(json|yaml|xml)$ ]]; then
  echo "Error: FORMAT must be empty or one of: json, yaml, xml." >&2
  exit 1
fi

if [[ -n "$FORMAT" ]]; then
  COLOR=0
  EMOJI=0
  UPDATE_CHECK=0
fi

VERSION_FILE="/etc/diskmark-version"
if [[ "$UPDATE_CHECK" -eq 1 ]] && [ -f "$VERSION_FILE" ]; then
  CURRENT_VERSION=$(cat "$VERSION_FILE")
  LATEST_VERSION=$(wget --no-check-certificate -qO- https://api.github.com/repos/e7db/docker-diskmark/releases/latest 2>/dev/null | grep '"tag_name"' | cut -d'"' -f4 || true)
  if [[ "$CURRENT_VERSION" != "unknown" ]] && is_semver "$CURRENT_VERSION" && is_semver "$LATEST_VERSION" && [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
    echo -e "Update available: \e[1;37m$CURRENT_VERSION\e[0m => \e[1;37m$LATEST_VERSION\e[0m (docker pull e7db/diskmark:latest)\n"
  fi
fi

detect_color_support() {
  if [[ "$TERM" == "dumb" ]]; then
    echo 0
  else
    echo 1
  fi
}

detect_emoji_support() {
  if [[ "$TERM" == "dumb" ]]; then
    echo 0
  else
    echo 1
  fi
}

if [[ -z "$COLOR" ]]; then
  COLOR=$(detect_color_support)
elif [[ ! "$COLOR" =~ ^[01]$ ]]; then
  echo "Error: COLOR must be either 0 or 1." >&2
  exit 1
fi
if [[ -z "$EMOJI" ]]; then
  EMOJI=$(detect_emoji_support)
elif [[ ! "$EMOJI" =~ ^[01]$ ]]; then
  echo "Error: EMOJI must be either 0 or 1." >&2
  exit 1
fi

RESET="0m"
NORMAL="0"
BOLD="1"
BLACK=";30m"
RED=";31m"
GREEN=";32m"
YELLOW=";33m"
BLUE=";34m"
MAGENTA=";35m"
CYAN=";36m"
WHITE=";37m"

function color() {
  if [[ "$COLOR" -eq 1 ]]; then
    echo "\e[$1$2"
  else
    echo ""
  fi
}

if [[ "$EMOJI" -eq 1 ]]; then
  SYM_SUCCESS="✅"
  SYM_FAILURE="❌"
  SYM_STOP="🛑"
else
  SYM_SUCCESS="[OK]"
  SYM_FAILURE="[FAIL]"
  SYM_STOP="[STOP]"
fi

function clean() {
  [[ -z $TARGET ]] && return
  if [[ -n $ISNEWDIR ]]; then
    rm -rf "$TARGET"
  else
    rm -f "$TARGET"/.diskmark.{json,tmp}
  fi
}

function interrupt() {
  local EXIT_CODE="${1:-0}"
  echo -e "\r\n\n$SYM_STOP The benchmark was $(color $BOLD $RED)interrupted$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo -e "$2"
  fi
  clean
  exit "${EXIT_CODE}"
}
trap 'interrupt $? "The benchmark was aborted before its completion."' HUP INT QUIT KILL TERM

function fail() {
  local EXIT_CODE="${1:-1}"
  echo -e "\r\n\n$SYM_FAILURE The benchmark had $(color $BOLD $RED)failed$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo -e "$2"
  fi
  clean
  exit "${EXIT_CODE}"
}
trap 'fail $? "The benchmark failed before its completion."' ERR

function error() {
  local EXIT_CODE="${1:-1}"
  echo -e "\r\n$SYM_FAILURE The benchmark encountered an $(color $BOLD $RED)error$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo -e "$2"
  fi
  clean
  exit "${EXIT_CODE}"
}

function requireCommand() {
  command -v "$1" >/dev/null 2>&1 || fail 1 "Missing required dependency: $(color $BOLD $WHITE)$1$(color $RESET). Please install it and try again."
}

function validateSizeString() {
  local VALUE="$1"
  local LABEL="$2"
  if [[ -z "$VALUE" ]]; then
    error 1 "$LABEL must be provided."
  fi
  if [[ ! "$VALUE" =~ ^[0-9]+([KkMmGgTtPp])?$ ]]; then
    error 1 "$LABEL must be a positive integer optionally followed by K, M, G, T, or P (example: 1G)."
  fi
  local BYTES=$(toBytes "$VALUE")
  if [[ -z "$BYTES" || "$BYTES" -le 0 ]]; then
    error 1 "$LABEL must be greater than zero."
  fi
}

function validateBinaryFlag() {
  local VALUE="$1"
  local LABEL="$2"
  if [[ ! "$VALUE" =~ ^[01]$ ]]; then
    error 1 "$LABEL must be either 0 or 1."
  fi
}

function validateRuntime() {
  local VALUE="$1"
  if [[ -z "$VALUE" ]]; then
    return 0
  fi
  if [[ ! "$VALUE" =~ ^[0-9]+(ms|s|m|h)$ ]]; then
    error 1 "RUNTIME must match the fio time format (e.g., 500ms, 5s, 2m, 1h)."
  fi
}

function validateInteger() {
  local VALUE="$1"
  local LABEL="$2"
  local ALLOW_ZERO="${3:-0}"
  local REGEX='^[1-9][0-9]*$'
  local ERROR_MSG="$LABEL must be a positive integer."

  if [[ "$ALLOW_ZERO" -eq 1 ]]; then
    REGEX='^[0-9]+$'
    ERROR_MSG="$LABEL must be a non-negative integer."
  fi

  if [[ -z "$VALUE" ]]; then
    error 1 "$LABEL must be provided."
  fi
  if [[ ! "$VALUE" =~ $REGEX ]]; then
    error 1 "$ERROR_MSG"
  fi
}

function ensureWritableTarget() {
  local PATH_TO_CHECK="$1"
  if [[ "$PATH_TO_CHECK" == "/" ]]; then
    error 1 "Refusing to run against the filesystem root. Please set TARGET to a dedicated directory."
  fi
  if [[ -d "$PATH_TO_CHECK" && ! -w "$PATH_TO_CHECK" ]]; then
    error 1 "TARGET directory is not writable: $PATH_TO_CHECK"
  fi
}

function toBytes() {
  local SIZE=$1
  local UNIT=${SIZE//[0-9]/}
  local NUMBER=${SIZE//[a-zA-Z]/}
  case $UNIT in
    P|p) echo $((NUMBER * 1024 * 1024 * 1024 * 1024 * 1024));;
    T|t) echo $((NUMBER * 1024 * 1024 * 1024 * 1024));;
    G|g) echo $((NUMBER * 1024 * 1024 * 1024));;
    M|m) echo $((NUMBER * 1024 * 1024));;
    K|k) echo $((NUMBER * 1024));;
    *) echo $NUMBER;;
  esac
}

function fromBytes() {
  local SIZE=$1
  local UNIT=""
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="K"
  fi
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="M"
  fi
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="G"
  fi
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="T"
  fi
  if (( SIZE > 1024 )); then
    SIZE=$((SIZE / 1024))
    UNIT="P"
  fi
  echo "${SIZE}${UNIT}"
}

function parseResult() {
  local bandwidth=$(cat "$TARGET/.diskmark.json" | grep -A"$2" '"name" : "'"$1"'"' | grep "$3" | sed 's/        "'"$3"'" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }')
  local throughput=$(cat "$TARGET/.diskmark.json" | grep -A"$2" '"name" : "'"$1"'"' | grep "$4" | sed 's/        "'"$4"'" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.0f", SUM }' | cut -d. -f1)
  echo "$(($bandwidth / 1024 / 1024)) MB/s, $throughput IO/s"
}

function parseReadResult() {
  parseResult "$1" 15 bw_bytes iops
}

function parseWriteResult() {
  parseResult "$1" 80 bw_bytes iops
}


function parseRandomReadResult() {
  parseResult "$1" 15 bw_bytes iops
}

function parseRandomWriteResult() {
  parseResult "$1" 80 bw_bytes iops
}

function loadDefaultProfile() {
  NAME=("SEQ1MQ8T1" "SEQ1MQ1T1" "RND4KQ32T1" "RND4KQ1T1")
  LABEL=("Sequential 1M Q8T1" "Sequential 1M Q1T1" "Random 4K Q32T1" "Random 4K Q1T1")
  JOBCOLOR=($(color $NORMAL $YELLOW) $(color $NORMAL $YELLOW) $(color $NORMAL $CYAN) $(color $NORMAL $CYAN))
  BLOCKSIZE=("1M" "1M" "4K" "4K")
  IODEPTH=(8 1 32 1)
  NUMJOBS=(1 1 1 1)
  READWRITE=("" "" "rand" "rand")
  SIZEDIVIDER=(-1 -1 16 32)
}

function loadNVMeProfile() {
  NAME=("SEQ1MQ8T1" "SEQ128KQ32T1" "RND4KQ32T16" "RND4KQ1T1")
  LABEL=("Sequential 1M Q8T1" "Sequential 128K Q32T1" "Random 4K Q32T16" "Random 4K Q1T1")
  JOBCOLOR=($(color $NORMAL $YELLOW) $(color $NORMAL $GREEN) $(color $NORMAL $CYAN) $(color $NORMAL $CYAN))
  BLOCKSIZE=("1M" "128K" "4K" "4K")
  IODEPTH=(8 32 32 1)
  NUMJOBS=(1 1 16 1)
  READWRITE=("" "" "rand" "rand")
  SIZEDIVIDER=(-1 -1 16 32)
}

function loadJob() {
  PARAMS=($(echo "$JOB" | perl -nle '/^(RND|SEQ)([0-9]+[KM])Q([0-9]+)T([0-9]+)$/; print "$1 $2 $3 $4"'))
  if [ -z ${PARAMS[0]} ]; then
    error 1 "Invalid job name: $(color $BOLD $WHITE)$JOB$(color $RESET)"
  fi

  case "${PARAMS[0]}" in
    RND)
      READWRITE=("rand")
      READWRITELABEL="Random"
      ;;
    SEQ)
      READWRITE=("")
      READWRITELABEL="Sequential"
      ;;
  esac
  BLOCKSIZE=(${PARAMS[1]})
  IODEPTH=(${PARAMS[2]})
  NUMJOBS=(${PARAMS[3]})

  NAME=($JOB)
  LABEL="$READWRITELABEL $BLOCKSIZE Q${IODEPTH}T${NUMJOBS}"
  JOBCOLOR=($(color $NORMAL $MAGENTA))
}

requireCommand fio
requireCommand dd
requireCommand awk
requireCommand df
if [[ -n "$JOB" ]]; then
  requireCommand perl
fi

TARGET="${TARGET:-$(pwd)}"
ensureWritableTarget "$TARGET"
if [ ! -d "$TARGET" ]; then
  ISNEWDIR=1
  mkdir -p "$TARGET"
fi

validateSizeString "${SIZE:-1G}" "SIZE"
validateBinaryFlag "${WARMUP:-0}" "WARMUP"
validateBinaryFlag "${DRY_RUN:-0}" "DRY_RUN"
if [[ -n "$WARMUP_SIZE" ]]; then
  validateSizeString "$WARMUP_SIZE" "WARMUP_SIZE"
fi
if [[ -n "$LOOPS" ]]; then
  validateInteger "$LOOPS" "LOOPS"
fi
if [[ -n "$RUNTIME" ]]; then
  validateRuntime "$RUNTIME"
fi
DRIVELABEL="Drive"

FILESYSTEMPARTITION=""
if command -v lsblk &> /dev/null; then
  FILESYSTEMPARTITION=$(lsblk -P 2>/dev/null | grep "$TARGET" | head -n 1 | awk '{print $1}' | cut -d"=" -f2 | cut -d"\"" -f2)
fi
if [ -z "$FILESYSTEMPARTITION" ] && command -v findmnt &> /dev/null; then
  FILESYSTEMPARTITION=$(findmnt -n -o SOURCE "$TARGET" 2>/dev/null | sed 's|/dev/||')
fi
if [ -z "$FILESYSTEMPARTITION" ]; then
  FILESYSTEMPARTITION=$(df "$TARGET" 2>/dev/null | tail +2 | awk '{print $1}' | sed 's|/dev/||')
fi

FILESYSTEMTYPE=$(df -T "$TARGET" | tail +2 | awk '{print $2}')
FILESYSTEMSIZE=$(df -Th "$TARGET" | tail +2 | awk '{print $3}')
ISOVERLAY=0
ISTMPFS=0
ISNVME=0
ISEMMC=0
ISMDADM=0
if [[ "$FILESYSTEMTYPE" == overlay ]]; then
  ISOVERLAY=1
elif [[ "$FILESYSTEMTYPE" == tmpfs ]]; then
  ISTMPFS=1
elif [[ "$FILESYSTEMPARTITION" == mmcblk* ]]; then
  DRIVE=$(echo $FILESYSTEMPARTITION | rev | cut -c 3- | rev)
  ISEMMC=1
elif [[ "$FILESYSTEMPARTITION" == nvme* ]]; then
  DRIVE=$(echo $FILESYSTEMPARTITION | rev | cut -c 3- | rev)
  ISNVME=1
elif [[ "$FILESYSTEMPARTITION" == hd* ]] || [[ "$FILESYSTEMPARTITION" == sd* ]] || [[ "$FILESYSTEMPARTITION" == vd* ]]; then
  DRIVE=$(echo $FILESYSTEMPARTITION | sed 's/[0-9]*$//')
elif [[ "$FILESYSTEMPARTITION" == md* ]]; then
  DRIVE=$FILESYSTEMPARTITION
  ISMDADM=1
else
  DRIVE=""
fi
if [ $ISOVERLAY -eq 1 ]; then
  DRIVENAME="Overlay"
  DRIVE="overlay"
  DRIVESIZE=$FILESYSTEMSIZE
elif [ $ISTMPFS -eq 1 ]; then
  DRIVENAME="RAM"
  DRIVE="tmpfs"
  DRIVESIZE=$(free -h --si | grep Mem: | awk '{print $2}')
elif [ $ISEMMC -eq 1 ]; then
  DEVICE=()
  if [ -f /sys/block/$DRIVE/device/type ]; then
    case "$(cat /sys/block/$DRIVE/device/type)" in
      SD) DEVICE+=("SD Card");;
      *) DEVICE+=();;
    esac
  fi
  [ -f /sys/block/$DRIVE/device/name ] && DEVICE+=($(cat /sys/block/$DRIVE/device/name | sed 's/ *$//g'))
  DRIVENAME=${DEVICE[@]:-"eMMC flash storage"}
  DRIVESIZE=$(fromBytes $(($(cat /sys/block/$DRIVE/size) * 512)))
elif [ $ISMDADM -eq 1 ]; then
  DRIVELABEL="Drives"
  DRIVENAME="mdadm $(cat /sys/block/$DRIVE/md/level)"
  DRIVESIZE=$(fromBytes $(($(cat /sys/block/$DRIVE/size) * 512)))
  DISKS=$(ls /sys/block/$DRIVE/slaves/)
  DRIVEDETAILS="using $(echo $DISKS | wc -w) disks ($(echo $DISKS | sed 's/ /, /g'))"
elif [ -d /sys/block/$DRIVE/device ]; then
  DEVICE=()
  [ -f /sys/block/$DRIVE/device/vendor ] && DEVICE+=($(cat /sys/block/$DRIVE/device/vendor | sed 's/ *$//g'))
  [ -f /sys/block/$DRIVE/device/model ] && DEVICE+=($(cat /sys/block/$DRIVE/device/model | sed 's/ *$//g'))
  DRIVENAME=${DEVICE[@]:-"Unknown drive"}
  DRIVESIZE=$(fromBytes $(($(cat /sys/block/$DRIVE/size) * 512)))
else
  DRIVE="Unknown"
  DRIVENAME="Unknown"
  DRIVESIZE="Unknown"
fi
if [ "$DRIVE" = "Unknown" ]; then
  DRIVEINFO="Unknown"
else
  DRIVEINFO="$DRIVENAME ($DRIVE, $DRIVESIZE) $DRIVEDETAILS"
fi
if [ ! -z $JOB ]; then
  PROFILE="Job \"$JOB\""
  loadJob
else
  case "$PROFILE" in
    ""|auto)
      if [ $ISNVME -eq 1 ]; then
        PROFILE="auto (nvme)"
        loadNVMeProfile
      else
        PROFILE="auto (default)"
        loadDefaultProfile
      fi
      ;;
    default)
      loadDefaultProfile
      ;;
    nvme)
      loadNVMeProfile
      ;;
    *)
      error 1 "Invalid PROFILE: $(color $BOLD $WHITE)$PROFILE$(color $RESET). Allowed values are 'auto', 'default', or 'nvme'."
      ;;
  esac
fi
case "$IO" in
  ""|direct)
    IO="direct (synchronous)"
    DIRECT=1
    ;;
  buffered)
    IO="buffered (asynchronous)"
    DIRECT=0
    ;;
  *)
    error 1 "Invalid IO mode: $(color $BOLD $WHITE)$IO$(color $RESET). Allowed values are 'direct' or 'buffered'."
    ;;
esac
case "$DATA" in
  ""|random|rand)
    DATA="random"
    WRITEZERO=0
    ;;
  zero | 0 | 0x00)
    DATA="zero (0x00)"
    WRITEZERO=1
    ;;
  *)
    error 1 "Invalid DATA pattern: $(color $BOLD $WHITE)$DATA$(color $RESET). Allowed values are 'random' or 'zero'."
    ;;
esac
SIZE="${SIZE:-1G}"
BYTESIZE=$(toBytes $SIZE)
WARMUP="${WARMUP:-0}"
if [ -z "$WARMUP_SIZE" ]; then
  case "$PROFILE" in
    *nvme*) WARMUP_SIZE="64M" ;;
    *) WARMUP_SIZE="8M" ;;
  esac
fi
validateSizeString "$WARMUP_SIZE" "WARMUP_SIZE"
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

if [[ -z "$FORMAT" ]]; then
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
fi

DRY_RUN="${DRY_RUN:-0}"
if [ "$DRY_RUN" -eq 1 ]; then
  echo -e "$SYM_SUCCESS Dry run $(color $BOLD $GREEN)completed$(color $RESET). Configuration is valid."
  exit 0
fi

if [[ -z "$FORMAT" ]]; then
  echo -e "The benchmark is $(color $BOLD $WHITE)running$(color $RESET), please wait..."
fi

TOTAL_JOBS=${#NAME[@]}

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

fio_benchmark() {
  fio --filename="$TARGET/.diskmark.tmp" \
    --stonewall --ioengine=libaio --direct=$DIRECT --zero_buffers=$WRITEZERO \
    $LIMIT_OPTION --size="$1" \
    --name="$2" --blocksize="$3" --iodepth="$4" --numjobs="$5" --readwrite="$6" \
    --output-format=json >"$TARGET/.diskmark.json"
}

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

RESULTS_NAME=()
RESULTS_STATUS=()
RESULTS_READ_BW=()
RESULTS_READ_IOPS=()
RESULTS_READ_LAT=()
RESULTS_WRITE_BW=()
RESULTS_WRITE_IOPS=()
RESULTS_WRITE_LAT=()
SKIPPED_JOBS=()

function parseResultRaw() {
  local bandwidth=$(cat "$TARGET/.diskmark.json" | grep -A"$2" '"name" : "'"$1"'"' | grep "$3" | sed 's/        "'"$3"'" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.6f", SUM / 1024 / 1024 }')
  local throughput=$(cat "$TARGET/.diskmark.json" | grep -A"$2" '"name" : "'"$1"'"' | grep "$4" | sed 's/        "'"$4"'" : //g' | sed 's:,::g' | awk '{ SUM += $1} END { printf "%.6f", SUM }')
  echo "$bandwidth $throughput"
}

function parseLatency() {
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

function formatLatency() {
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

function escapeJson() {
  echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g'
}

function outputResults() {
  local total=${#RESULTS_NAME[@]}
  case "$FORMAT" in
    "")
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
      ;;
    json)
      echo "{"
      echo "  \"configuration\": {"
      echo "    \"target\": \"$(escapeJson "$TARGET")\","
      echo "    \"drive\": {"
      echo "      \"label\": \"$(escapeJson "$DRIVELABEL")\","
      echo "      \"info\": \"$(escapeJson "$DRIVEINFO")\""
      echo "    },"
      echo "    \"filesystem\": {"
      echo "      \"type\": \"$(escapeJson "$FILESYSTEMTYPE")\","
      echo "      \"partition\": \"$(escapeJson "$FILESYSTEMPARTITION")\","
      echo "      \"size\": \"$(escapeJson "$FILESYSTEMSIZE")\""
      echo "    },"
      echo "    \"profile\": \"$(escapeJson "$PROFILE")\","
      echo "    \"io\": \"$(escapeJson "$IO")\","
      echo "    \"data\": \"$(escapeJson "$DATA")\","
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
        echo -n "    {\"name\": \"$(escapeJson "${RESULTS_NAME[$j]}")\", \"status\": \"${RESULTS_STATUS[$j]}\""
        if [[ "${RESULTS_STATUS[$j]}" != "skipped" ]]; then
          echo -n ", \"read\": {\"bandwidth_mb\": ${RESULTS_READ_BW[$j]}, \"iops\": ${RESULTS_READ_IOPS[$j]}, \"latency_ms\": ${RESULTS_READ_LAT[$j]}}, \"write\": {\"bandwidth_mb\": ${RESULTS_WRITE_BW[$j]}, \"iops\": ${RESULTS_WRITE_IOPS[$j]}, \"latency_ms\": ${RESULTS_WRITE_LAT[$j]}}"
        fi
        echo -n "}"
        [[ $j -lt $((total - 1)) ]] && echo "," || echo
      done
      echo "  ]"
      echo "}"
      ;;
    yaml)
      echo "configuration:"
      echo "  target: \"$(escapeJson "$TARGET")\""
      echo "  drive:"
      echo "    label: \"$(escapeJson "$DRIVELABEL")\""
      echo "    info: \"$(escapeJson "$DRIVEINFO")\""
      echo "  filesystem:"
      echo "    type: \"$(escapeJson "$FILESYSTEMTYPE")\""
      echo "    partition: \"$(escapeJson "$FILESYSTEMPARTITION")\""
      echo "    size: \"$(escapeJson "$FILESYSTEMSIZE")\""
      echo "  profile: \"$(escapeJson "$PROFILE")\""
      echo "  io: \"$(escapeJson "$IO")\""
      echo "  data: \"$(escapeJson "$DATA")\""
      echo "  size: \"$SIZE\""
      echo "  warmup: $WARMUP"
      if [[ -n "$LOOPS" ]]; then
        echo "  loops: $LOOPS"
      else
        echo "  runtime: \"$RUNTIME\""
      fi
      echo "results:"
      for ((j = 0; j < total; j++)); do
        echo "  - name: \"$(escapeJson "${RESULTS_NAME[$j]}")\""
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
      ;;
    xml)
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
      ;;
  esac
}

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

  case "${READWRITE[$i]}" in
    rand) PARSE="parseRandom" ;;
    *) PARSE="parse" ;;
  esac

  show_progress "$JOB_NUM" "${NAME[$i]} read"
  fio_benchmark "$TESTSIZE" "${NAME[$i]}Read" "${BLOCKSIZE[$i]}" "${IODEPTH[$i]}" "${NUMJOBS[$i]}" "${READWRITE[$i]}read"
  READ_RAW=$(parseResultRaw "${NAME[$i]}Read" 15 bw_bytes iops)
  READ_BW=$(echo "$READ_RAW" | awk '{print $1}')
  READ_IOPS=$(echo "$READ_RAW" | awk '{print $2}')
  READ_LAT=$(parseLatency "${NAME[$i]}Read" "read")
  show_progress "$JOB_NUM" "${NAME[$i]} write"
  fio_benchmark "$TESTSIZE" "${NAME[$i]}Write" "${BLOCKSIZE[$i]}" "${IODEPTH[$i]}" "${NUMJOBS[$i]}" "${READWRITE[$i]}write"
  WRITE_RAW=$(parseResultRaw "${NAME[$i]}Write" 80 bw_bytes iops)
  WRITE_BW=$(echo "$WRITE_RAW" | awk '{print $1}')
  WRITE_IOPS=$(echo "$WRITE_RAW" | awk '{print $2}')
  WRITE_LAT=$(parseLatency "${NAME[$i]}Write" "write")
  if [[ -z "$FORMAT" ]]; then
    clear_progress
    echo -e "${JOBCOLOR[$i]}${LABEL[$i]}:$(color $RESET)"
    printf "<= Read:  %.0f MB/s, %.0f IO/s, %s\n" "$READ_BW" "$READ_IOPS" "$(formatLatency $READ_LAT)"
    printf "=> Write: %.0f MB/s, %.0f IO/s, %s\n" "$WRITE_BW" "$WRITE_IOPS" "$(formatLatency $WRITE_LAT)"
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

outputResults

clean
