#!/bin/bash
# profiles.sh - Benchmark profile definitions
# Provides: load_default_profile, load_nvme_profile, load_job, select_profile

load_default_profile() {
  NAME=("SEQ1MQ8T1" "SEQ1MQ1T1" "RND4KQ32T1" "RND4KQ1T1")
  LABEL=("Sequential 1M Q8T1" "Sequential 1M Q1T1" "Random 4K Q32T1" "Random 4K Q1T1")
  JOBCOLOR=($(color $NORMAL $YELLOW) $(color $NORMAL $YELLOW) $(color $NORMAL $CYAN) $(color $NORMAL $CYAN))
  BLOCKSIZE=("1M" "1M" "4K" "4K")
  IODEPTH=(8 1 32 1)
  NUMJOBS=(1 1 1 1)
  READWRITE=("" "" "rand" "rand")
  SIZEDIVIDER=(-1 -1 16 32)
}

load_nvme_profile() {
  NAME=("SEQ1MQ8T1" "SEQ128KQ32T1" "RND4KQ32T16" "RND4KQ1T1")
  LABEL=("Sequential 1M Q8T1" "Sequential 128K Q32T1" "Random 4K Q32T16" "Random 4K Q1T1")
  JOBCOLOR=($(color $NORMAL $YELLOW) $(color $NORMAL $GREEN) $(color $NORMAL $CYAN) $(color $NORMAL $CYAN))
  BLOCKSIZE=("1M" "128K" "4K" "4K")
  IODEPTH=(8 32 32 1)
  NUMJOBS=(1 1 16 1)
  READWRITE=("" "" "rand" "rand")
  SIZEDIVIDER=(-1 -1 16 32)
}

load_job() {
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
  SIZEDIVIDER=(-1)
}

select_profile() {
  if [ ! -z $JOB ]; then
    PROFILE="Job \"$JOB\""
    load_job
  else
    case "$PROFILE" in
      ""|auto)
        if [ $ISNVME -eq 1 ]; then
          PROFILE="auto (nvme)"
          load_nvme_profile
        else
          PROFILE="auto (default)"
          load_default_profile
        fi
        ;;
      default)
        load_default_profile
        ;;
      nvme)
        load_nvme_profile
        ;;
      *)
        error 1 "Invalid PROFILE: $(color $BOLD $WHITE)$PROFILE$(color $RESET). Allowed values are 'auto', 'default', or 'nvme'."
        ;;
    esac
  fi
}
