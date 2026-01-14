#!/bin/bash
# args.sh - CLI argument parsing and help display
# Provides: show_help, show_version, parse_args

VERSION_FILE="/etc/diskmark-version"
if [ -f "$VERSION_FILE" ]; then
  SCRIPT_VERSION=$(cat "$VERSION_FILE")
elif command -v git &>/dev/null && git rev-parse --short HEAD &>/dev/null; then
  GIT_DESC=$(git describe --tags --always 2>/dev/null)
  if [[ "$GIT_DESC" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    SCRIPT_VERSION="${BASH_REMATCH[1]}"
  elif [[ "$GIT_DESC" =~ ^v?([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)-g([a-f0-9]+)$ ]]; then
    SCRIPT_VERSION="${BASH_REMATCH[1]}-dev.${BASH_REMATCH[2]}+${BASH_REMATCH[3]}"
  else
    SCRIPT_VERSION="0.0.0-dev+$(git rev-parse --short HEAD)"
  fi
else
  SCRIPT_VERSION="unknown"
fi

show_help() {
  cat << EOF
Docker DiskMark - A fio-based disk benchmark tool
Version: $SCRIPT_VERSION

Usage: diskmark [OPTIONS]

Options:
  -h, --help                 Show this help message and exit
  -v, --version              Show version information and exit

  -t, --target PATH          Target directory for benchmark (default: /disk or \$PWD)
  -p, --profile PROFILE      Benchmark profile: auto, default, nvme (default: auto)
  -j, --job JOB              Custom job definition (e.g., RND4KQ32T16)
                             Overrides --profile when specified

  -i, --io MODE              I/O mode: direct, buffered (default: direct)
  -d, --data PATTERN         Data pattern: random, zero (default: random)
  -s, --size SIZE            Test file size (e.g., 500M, 1G, 10G) (default: 1G)

  -w, --warmup               Enable warmup phase (default: enabled)
      --no-warmup            Disable warmup phase
      --warmup-size SIZE     Warmup block size (default: 8M for default, 64M for nvme)

  -r, --runtime DURATION     Runtime per job (e.g., 500ms, 5s, 2m) (default: 5s)
  -l, --loops COUNT          Number of test loops to run
                             Can be combined with --runtime to cap each loop

  -n, --dry-run              Validate configuration without running benchmark
  -f, --format FORMAT        Output format: json, yaml, xml (default: human-readable)
  -u, --no-update-check      Disable update check at startup

      --color                Force colored output
      --no-color             Disable colored output
      --emoji                Force emoji output
      --no-emoji             Disable emoji output

Environment Variables:
  All options can also be set via environment variables:
    TARGET, PROFILE, JOB, IO, DATA, SIZE, WARMUP, WARMUP_SIZE,
    RUNTIME, LOOPS, DRY_RUN, FORMAT, UPDATE_CHECK, COLOR, EMOJI

  CLI arguments take precedence over environment variables.

Examples:
  diskmark --size 4G --warmup --loops 2
  diskmark -s 1G -r 10s -p nvme
  diskmark --job RND4KQ32T16 --format json
  diskmark -t /mnt/data -w -d zero

For more information, visit: https://github.com/e7db/docker-diskmark
EOF
  exit 0
}

show_version() {
  echo "Docker DiskMark version $SCRIPT_VERSION"
  exit 0
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        ;;
      -v|--version)
        show_version
        ;;
      -t|--target)
        TARGET="$2"
        shift 2
        ;;
      --target=*)
        TARGET="${1#*=}"
        shift
        ;;
      -p|--profile)
        PROFILE="$2"
        shift 2
        ;;
      --profile=*)
        PROFILE="${1#*=}"
        shift
        ;;
      -j|--job)
        JOB="$2"
        shift 2
        ;;
      --job=*)
        JOB="${1#*=}"
        shift
        ;;
      -i|--io)
        IO="$2"
        shift 2
        ;;
      --io=*)
        IO="${1#*=}"
        shift
        ;;
      -d|--data)
        DATA="$2"
        shift 2
        ;;
      --data=*)
        DATA="${1#*=}"
        shift
        ;;
      -s|--size)
        SIZE="$2"
        shift 2
        ;;
      --size=*)
        SIZE="${1#*=}"
        shift
        ;;
      -w|--warmup)
        WARMUP=1
        shift
        ;;
      --no-warmup)
        WARMUP=0
        shift
        ;;
      --warmup-size)
        WARMUP_SIZE="$2"
        shift 2
        ;;
      --warmup-size=*)
        WARMUP_SIZE="${1#*=}"
        shift
        ;;
      -r|--runtime)
        RUNTIME="$2"
        shift 2
        ;;
      --runtime=*)
        RUNTIME="${1#*=}"
        shift
        ;;
      -l|--loops)
        LOOPS="$2"
        shift 2
        ;;
      --loops=*)
        LOOPS="${1#*=}"
        shift
        ;;
      -n|--dry-run)
        DRY_RUN=1
        shift
        ;;
      -f|--format)
        FORMAT="$2"
        shift 2
        ;;
      --format=*)
        FORMAT="${1#*=}"
        shift
        ;;
      -u|--no-update-check)
        UPDATE_CHECK=0
        shift
        ;;
      --color)
        COLOR=1
        shift
        ;;
      --no-color)
        COLOR=0
        shift
        ;;
      --emoji)
        EMOJI=1
        shift
        ;;
      --no-emoji)
        EMOJI=0
        shift
        ;;
      -*)
        echo "Error: Unknown option: $1" >&2
        echo "Use --help for usage information." >&2
        exit 1
        ;;
      *)
        echo "Error: Unexpected argument: $1" >&2
        echo "Use --help for usage information." >&2
        exit 1
        ;;
    esac
  done
}
