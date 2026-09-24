#!/usr/bin/env bash
# line_guard.sh MAX [--strict]
#
# Copy stdin to stdout, cutting every line longer than MAX characters to MAX
# and saying how much was cut. With --strict, also exit 1 if any line was cut,
# naming how many and the longest.
#
# WHY. The GitHub Actions runner spends time QUADRATIC in a line's length on
# every line a step prints, and while it is inside one line it neither drains
# the step's stdout nor services the step's timeout-minutes or a cancel.
# Measured on ubuntu-latest with no ailang involved (LEG-CI-COMPACTION, runs
# 36018119963 and 36018131861): 1 MB as 1000 short lines 4 s; ONE line of
# 64 KB 7 s, of 256 KB 104-129 s. long_qwen_compaction_dst prints single lines
# of 838 KB and 1.05 MB -- about 50 minutes of runner time -- so `DST gates
# (rest)` ran past every timeout it had and was reported "cancelled" with no
# log, for weeks, while the same script passes in 7 s once its output is not
# on the runner's pipe.
#
# A recipe that knowingly prints long lines cuts its own (compaction_dst's
# long_qwen line). CI puts the whole DST line through --strict at a higher
# bound, so the NEXT producer of long lines is a fast red with a name.
set -u

max=${1:?usage: line_guard.sh MAX [--strict]}
strict=${2:-}

awk -v max="$max" -v strict="$strict" '
  {
    n = length($0)
    if (n > max) {
      cut++
      if (n > longest) longest = n
      print substr($0, 1, max) " ...[line_guard: " n - max " of " n " chars cut]"
    } else {
      print
    }
    fflush()
  }
  END {
    if (cut && strict == "--strict") {
      printf "::error title=line_guard::%d line(s) over %d chars, the longest %d. The GitHub runner spends time quadratic in line length on each (1 MB: ~30 min) and services no timeout meanwhile; bound the producer. See scripts/line_guard.sh.\n", cut, max, longest
      exit 1
    }
  }'
