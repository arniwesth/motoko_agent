#!/usr/bin/env bash
# compare_gates.sh <base-logdir> <seeded-logdir> — the gates' verdicts, not their timings.
b="$1"; s="$2"
echo "# Gate comparison: $(basename $b) (unseeded) vs $(basename $s) (seeded)"
echo "## exit codes"; paste <(sed -E 's/ secs=[0-9]+//' $b/SUMMARY) <(sed -E 's/ secs=[0-9]+//' $s/SUMMARY) | awk -F'\t' '{print ($1==$2?"SAME ":"DIFF ") $1 "  |  " $2}'
v() { # verdict lines of a log, order-independent
  sed -E 's/\x1b\[[0-9;]*m//g' "$1" | grep -aE '^\s*(✓|✗|OK|FAIL|PASS)|^(PASS|FAIL) src/|Tests:|Test Suites:|passed|failed|Passed:|Failed:|proven|verify_core:|type-check:' \
    | sed -E 's/[0-9.]+µs//g; s/\([0-9.]+ ?m?s\)//g; s/[0-9]+(\.[0-9]+)? ?m?s\b//g; s/elapsed_ms=[0-9]+//; s/return_ms=[0-9]+ timeout_ms=[0-9]+//; s/marker_ms_after_kill~[0-9]+//; s/ ?\(\)//g; s/ +$//' | sort
}
for f in $b/*.log; do n=$(basename $f)
  if diff <(v $f) <(v $s/$n) > /dev/null; then echo "SAME verdicts ($(v $f | wc -l) lines): $n"; else echo "DIFF verdicts: $n"; diff <(v $f) <(v $s/$n) | head -10 | sed 's/^/    /'; fi
done
echo "## bun"; grep -ahE '^(Test Suites|Tests):' $b/bun_test.log $s/bun_test.log
echo "failing suites, unseeded:"; grep -a '^FAIL' $b/bun_test.log | sort | sed 's/^/    /'
echo "failing suites identical: $(cmp -s <(grep -a '^FAIL' $b/bun_test.log | sort) <(grep -a '^FAIL' $s/bun_test.log | sort) && echo yes || echo no)"
echo "## ailang lock warning (first line of each log that has one)"
for d in $b $s; do echo "  $(basename $d): $(grep -ah 'content changed' $d/*.log | sed -E 's/\(locked.*//' | sort -u | tr '\n' ' ')"; done
