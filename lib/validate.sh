#!/bin/bash
# validate.sh - Input validation functions
# Provides: validate_* functions for all input parameters

validate_size_string() {
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

validate_binary_flag() {
  local VALUE="$1"
  local LABEL="$2"
  if [[ ! "$VALUE" =~ ^[01]$ ]]; then
    error 1 "$LABEL must be either 0 or 1."
  fi
}

validate_runtime() {
  local VALUE="$1"
  if [[ -z "$VALUE" ]]; then
    return 0
  fi
  if [[ ! "$VALUE" =~ ^[0-9]+(ms|s|m|h)$ ]]; then
    error 1 "RUNTIME must match the fio time format (e.g., 500ms, 5s, 2m, 1h)."
  fi
}

validate_integer() {
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

ensure_writable_target() {
  local PATH_TO_CHECK="$1"
  if [[ "$PATH_TO_CHECK" == "/" ]]; then
    error 1 "Refusing to run against the filesystem root. Please set TARGET to a dedicated directory."
  fi
  if [[ -d "$PATH_TO_CHECK" && ! -w "$PATH_TO_CHECK" ]]; then
    error 1 "TARGET directory is not writable: $PATH_TO_CHECK"
  fi
}

validate_format() {
  FORMAT="${FORMAT:-}"
  if [[ -n "$FORMAT" && ! "$FORMAT" =~ ^(json|yaml|xml)$ ]]; then
    echo "Error: FORMAT must be empty or one of: json, yaml, xml." >&2
    exit 1
  fi
  # Machine-readable formats disable display features
  if [[ -n "$FORMAT" ]]; then
    COLOR=0
    EMOJI=0
    UPDATE_CHECK=0
  fi
}

validate_update_check() {
  UPDATE_CHECK="${UPDATE_CHECK:-1}"
  if [[ ! "$UPDATE_CHECK" =~ ^[01]$ ]]; then
    echo "Error: UPDATE_CHECK must be either 0 or 1." >&2
    exit 1
  fi
}

validate_io_mode() {
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
}

validate_data_pattern() {
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
}

validate_all_inputs() {
  validate_update_check
  validate_format
  validate_size_string "${SIZE:-1G}" "SIZE"
  validate_binary_flag "${WARMUP:-1}" "WARMUP"
  validate_binary_flag "${DRY_RUN:-0}" "DRY_RUN"
  if [[ -n "$WARMUP_SIZE" ]]; then
    validate_size_string "$WARMUP_SIZE" "WARMUP_SIZE"
  fi
  if [[ -n "$LOOPS" ]]; then
    validate_integer "$LOOPS" "LOOPS"
  fi
  if [[ -n "$RUNTIME" ]]; then
    validate_runtime "$RUNTIME"
  fi
}
