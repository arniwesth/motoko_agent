#!/usr/bin/env bash
# Vacuity check by mutation (RESEARCH §4: a theorem should fail on a mutant model). Files come
# from make_mutants.py: on each one-line mutant of the model, the TARGET `bug_` statement must
# evaluate to false (it cannot be proved there) and the CONTROL statement must stay true.
# Exit 0 when every mutant passes.
here="$(cd "$(dirname "$0")" && pwd)"
LEAN="${LEAN:-$HOME/.elan/toolchains/leanprover--lean4---v4.28.0/bin/lean}"
all=0
for m in "$here"/M*.lean; do
  out="$(timeout 300 "$LEAN" "$m" 2>&1)"
  t=$(printf '%s\n' "$out" | grep -oE '^TARGET [a-z0-9_]+ (true|false)')
  c=$(printf '%s\n' "$out" | grep -oE '^CONTROL [a-z0-9_]+ (true|false)')
  if [[ "$t" == *false && "$c" == *true ]]; then v=PASS; else v=FAIL; all=1; fi
  echo "$(basename "$m" .lean): $t; $c -> $v"
done
exit $all
