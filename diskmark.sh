#!/bin/bash
# diskmark - A fio-based disk benchmark tool
# Main entry point - sources modular components

set -e

if [ -d "/usr/lib/diskmark" ]; then
  LIB_DIR="/usr/lib/diskmark"
elif [ -d "$(dirname "$0")/../lib" ]; then
  LIB_DIR="$(dirname "$0")/../lib"
else
  LIB_DIR="$(dirname "$0")/lib"
fi

source "$LIB_DIR/utils.sh"
source "$LIB_DIR/args.sh"
source "$LIB_DIR/validate.sh"
source "$LIB_DIR/detect.sh"
source "$LIB_DIR/profiles.sh"
source "$LIB_DIR/benchmark.sh"
source "$LIB_DIR/output.sh"
source "$LIB_DIR/update.sh"

main() {
  parse_args "$@"

  validate_update_check
  validate_format
  check_for_updates
  init_display_settings
  setup_traps

  require_command fio
  require_command dd
  require_command awk
  require_command df
  if [[ -n "$JOB" ]]; then
    require_command perl
  fi

  TARGET="${TARGET:-$(pwd)}"
  ensure_writable_target "$TARGET"
  if [ ! -d "$TARGET" ]; then
    ISNEWDIR=1
    mkdir -p "$TARGET"
  fi

  validate_all_inputs
  detect_all
  select_profile
  validate_io_mode
  validate_data_pattern
  prepare_benchmark_params

  if [[ -z "$FORMAT" ]]; then
    output_config_human
  fi

  DRY_RUN="${DRY_RUN:-0}"
  if [ "$DRY_RUN" -eq 1 ]; then
    output_dry_run_success
    exit 0
  fi

  output_running_message
  run_warmup
  run_all_benchmarks
  output_results
  clean
}

main "$@"
