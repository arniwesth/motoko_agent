#!/usr/bin/env bash
#
# Mutation checks for the Z3 contracts on src/core's guard predicates.
#
# `ailang verify` reporting VERIFIED proves the contract holds of the body. It
# does not prove the contract would notice if the body changed -- a contract
# that is a tautology also verifies, and verifies forever. These cases delete
# one disjunct from a guard's body and assert the solver returns VIOLATION with
# the expected counterexample, so each recall contract is falsified in CI rather
# than merely satisfied.
#
# See .agent/projects/027_z3_contracts/ -- PLAN P5 ("the mutation check is part
# of the deliverable, not a nicety") and RESEARCH §3 E7 for the measurements.
#
# Each case mutates a tracked source file IN PLACE and restores it on exit,
# including on interrupt. It must therefore never run inside a gate that DP7 or
# another agent depends on; `make verify_mutations` is its only caller.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

BACKUP_DIR="$(mktemp -d)"
restore() {
  local rc=$?
  for b in "$BACKUP_DIR"/*.bak; do
    [ -e "$b" ] || continue
    local target
    target="$(cat "$b.path")"
    cp "$b" "$target"
  done
  rm -rf "$BACKUP_DIR"
  return $rc
}
trap restore EXIT INT TERM

pass=0
fail=0

# run_case <file> <function> <exact-body-line-to-delete> <expected-counterexample>
run_case() {
  local file="$1" fn="$2" line="$3" want="$4"
  local tag; tag="$(echo "$fn" | tr -c 'A-Za-z0-9' '_')"
  local bak="$BACKUP_DIR/$tag.bak"

  cp "$file" "$bak"
  printf '%s' "$file" > "$bak.path"

  if ! grep -Fxq -- "$line" "$file"; then
    echo "  ✗ $fn: mutation target not found in $file"
    echo "      looked for: $line"
    echo "      The body changed shape; update this case rather than deleting it."
    fail=$((fail + 1))
    return
  fi

  awk -v L="$line" 'BEGIN { done = 0 }
    { if (!done && $0 == L) { done = 1; next } print }' "$bak" > "$file"

  local out
  out="$(ailang verify "$file" 2>&1 || true)"
  cp "$bak" "$file"

  if ! echo "$out" | grep -q "VIOLATION $fn"; then
    echo "  ✗ $fn: body mutated, contract still holds -- it does not constrain this line"
    echo "      deleted: $line"
    echo "$out" | grep -E "VERIFIED $fn|SKIPPED $fn" | sed 's/^/      /'
    fail=$((fail + 1))
    return
  fi

  if ! echo "$out" | grep -qF "$want"; then
    echo "  ~ $fn: VIOLATION as expected, but not the counterexample recorded here"
    echo "      expected to see: $want"
    echo "$out" | grep -A6 "VIOLATION $fn" | sed 's/^/      /'
    fail=$((fail + 1))
    return
  fi

  echo "  ✓ $fn: deleting \`$(echo "$line" | sed 's/^ *//')\` yields VIOLATION ($want)"
  pass=$((pass + 1))
}

echo "verify_mutations: falsifying the guard contracts in src/core/"

run_case src/core/tool_runtime.ail has_shell_tokens \
  '    || contains(s, ";")' \
  '$p_s: String = ";"'

run_case src/core/tool_runtime.ail shell_command_needs_wrap \
  '    || cmd == "sh"' \
  '$p_cmd: String = "sh"'

run_case src/core/tool_runtime.ail starts_with_root_dir \
  '  startsWith(path, "Users/")   ||' \
  'Users/'

# The retry bound. Unlike the two above this is a PRECISION property, so the
# mutation is the conjunct whose loss would let a retry through with no budget
# left to spend on it -- the edit that turns a bounded retry into an unbounded one.
run_case src/core/recovery.ail should_retry_stream_error \
  '    && remaining_step_budget > 1' \
  'remaining_step_budget'

# The trace redaction guard. One call site (session.ail:262,
# `if trace_sensitive_key(key) then js("[redacted]")`) and no test, so this case
# and the contract are its only mechanical coverage. Dropping a key here is how
# a secret reaches the trace.
run_case src/core/session.ail trace_sensitive_key \
  '    || key == "cmd"' \
  '$p_key: String = "cmd"'

echo "verify_mutations: $pass falsified, $fail unfalsified"
[ "$fail" -eq 0 ]
