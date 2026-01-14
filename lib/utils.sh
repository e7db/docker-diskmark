#!/bin/bash
# utils.sh - Utility functions for diskmark
# Provides: color output, size conversions, cleanup, error handling

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

init_display_settings() {
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

  if [[ "$EMOJI" -eq 1 ]]; then
    SYM_SUCCESS="✅"
    SYM_FAILURE="❌"
    SYM_STOP="🛑"
  else
    SYM_SUCCESS="[OK]"
    SYM_FAILURE="[FAIL]"
    SYM_STOP="[STOP]"
  fi
}

color() {
  if [[ "$COLOR" -eq 1 ]]; then
    echo "\e[$1$2"
  else
    echo ""
  fi
}

toBytes() {
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

fromBytes() {
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

clean() {
  [[ -z $TARGET ]] && return
  if [[ -n $ISNEWDIR ]]; then
    rm -rf "$TARGET"
  else
    rm -f "$TARGET"/.diskmark.{json,tmp}
  fi
}

interrupt() {
  local EXIT_CODE="${1:-0}"
  echo -e "\r\n\n$SYM_STOP The benchmark was $(color $BOLD $RED)interrupted$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo -e "$2"
  fi
  clean
  exit "${EXIT_CODE}"
}

fail() {
  local EXIT_CODE="${1:-1}"
  echo -e "\r\n\n$SYM_FAILURE The benchmark had $(color $BOLD $RED)failed$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo -e "$2"
  fi
  clean
  exit "${EXIT_CODE}"
}

error() {
  local EXIT_CODE="${1:-1}"
  echo -e "\r\n$SYM_FAILURE The benchmark encountered an $(color $BOLD $RED)error$(color $RESET)."
  if [ ! -z "$2" ]; then
    echo -e "$2"
  fi
  clean
  exit "${EXIT_CODE}"
}

setup_traps() {
  trap 'interrupt $? "The benchmark was aborted before its completion."' HUP INT QUIT KILL TERM
  trap 'fail $? "The benchmark failed before its completion."' ERR
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail 1 "Missing required dependency: $(color $BOLD $WHITE)$1$(color $RESET). Please install it and try again."
}
