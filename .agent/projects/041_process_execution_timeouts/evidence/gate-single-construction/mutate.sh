#!/usr/bin/env bash
# 041 gate: prove `verify_single_construction` can fail `check_core`, one row at a time.
# Run from the worktree root on a commit whose src, packages, scripts and Makefile are clean:
#   env -u AILANG_FS_SANDBOX mutate.sh <log directory>
# Writes mutants.tsv and commit there, and leaves each row's raw output beside them.
#
# A red row counts only when all of these hold:
#   - the script itself exits with the row's code (1 a breach, 2 could not check)
#   - it says so for the row's own reason
#   - `make verify_single_construction` fails, naming the script's code as `Error <code>`
#   - `make check_core` fails, and its last line names this target and that code
#   - the type-check step did not run, so nothing later in check_core could have failed it
# make's own exit status is 2 for any failed recipe, so it cannot tell 1 from 2. `Error <code>` can.
# g1, g2, g5 and g6 also run `ailang check` on the file: it must pass, or the compiler would have
# caught the breach (or the legal caller is not legal) and the row would show nothing about this gate.
# g7 is the other way round: `ailang check` must refuse it. The checker's exemption for an update
# naming a non-result field rests on that refusal, so if AILANG ever allows it this row goes red.
set -u
OUT=${1:?log directory}
M=src/core/process_limits.ail
F=scripts/gate_forged.ail
CHECK=scripts/verify_single_construction.py
T=verify_single_construction
KEEP=$(mktemp -d)
clean() { [ -z "$(git status --porcelain -- src packages scripts Makefile)" ]; }
clean || { echo "src, packages, scripts or Makefile dirty"; exit 2; }
COMMIT=$(git rev-parse HEAD)
TSV=$OUT/mutants.tsv
printf 'id\trule\tedit\texpected\tcommit\tobserved\tverdict\n' >"$TSV"

restore() {
  rm -f "$F"
  git reset -q -- "$M"
  [ -f "$KEEP/module" ] && mv "$KEEP/module" "$M"
  git checkout -q -- "$M"
  clean || { echo "did not restore"; exit 2; }
}
trap restore EXIT

row() { # id rule edit expected-code reason-text
  local id=$1 rule=$2 desc=$3 want=$4 reason=$5 verdict=killed rc typed=- trc crc
  case "$id" in
    g1|g2|g5*|g6*)
      ailang check "$F" >"$OUT/$id.ailang" 2>&1; typed=$?
      [ "$typed" = 0 ] || verdict=not-well-typed ;;
    g7)
      ailang check "$F" >"$OUT/$id.ailang" 2>&1; typed=$?
      [ "$typed" != 0 ] && grep -qF "record field 'task' not found" "$OUT/$id.ailang" || verdict=survived ;;
  esac
  python3 "$CHECK" >"$OUT/$id.script" 2>&1; rc=$?
  make "$T" >"$OUT/$id.target" 2>&1; trc=$?
  make check_core >"$OUT/$id.check_core" 2>&1; crc=$?
  local last; last=$(grep -E '^make: \*\*\*|^src/core/ type-check:' "$OUT/$id.check_core" | tail -1)
  [ "$rc" = "$want" ] || verdict=survived
  grep -qF "$reason" "$OUT/$id.script" || verdict=survived
  if [ "$want" = 0 ]; then
    [ "$trc" = 0 ] && [ "$crc" = 0 ] || verdict=survived
    grep -q '^src/core/ type-check: .* 0 failed' "$OUT/$id.check_core" || verdict=survived
    [ "$verdict" = killed ] && verdict=passed
  else
    [ "$trc" != 0 ] && grep -q "\[Makefile:[0-9]*: $T\] Error $want" "$OUT/$id.target" || verdict=survived
    [ "$crc" != 0 ] || verdict=survived
    echo "$last" | grep -q "\[Makefile:[0-9]*: $T\] Error $want" || verdict=survived
    grep -q '^src/core/ type-check:' "$OUT/$id.check_core" && verdict=survived
  fi
  local obs="ailang_check=$typed script=$rc make_target=$trc make_check_core=$crc | $(tail -1 "$OUT/$id.script") | $last"
  printf '%s\t%s\t%s\texit %s\t%s\t%s\t%s\n' "$id" "$rule" "$desc" "$want" "${COMMIT:0:8}" "$obs" "$verdict" >>"$TSV"
  echo "$id: $verdict | $obs"
  restore
}

printf 'module scripts/gate_forged\nimport std/option (None)\nimport src/core/process_limits (ResolvedProcess, NoDeadline, SameAsDefault, SessionDefault)\nexport pure func forged() -> ResolvedProcess = { budget: SessionDefault, requested_ms: None, clamped: false, session_default: NoDeadline, effective_ceiling: SameAsDefault }\n' >"$F"
row g1 'D7: only the resolver builds a result' 'another module writes the ResolvedProcess literal' 1 'result label `session_default` written outside the resolver'

printf 'module scripts/gate_forged\nimport src/core/process_limits (ResolvedProcess, ProcessBudget, SessionDefault)\nexport pure func forged(r: ResolvedProcess) -> ResolvedProcess = { r | budget: SessionDefault }\n' >"$F"
row g2 'D7: only the resolver builds a result' 'another module updates budget, the field only the record-update rule sees' 1 'record update of result field `budget`'

mv "$M" "$KEEP/module"
row g3 'exit 2 is not a pass' 'the module is moved off disk and stays in the index' 2 "cannot check: $M is not there"

mv "$M" "$KEEP/module"
git rm -q --cached "$M"
row g3.index 'exit 2 is not a pass' 'the module is moved off disk and out of the index' 2 "cannot check: $M is not there"

row g4 'clean control: the gate passes for the right reason' 'none' 0 'check_single_construction:'

printf 'module scripts/gate_forged\nimport src/core/process_limits (ResolvedProcess, ExplicitMs)\npure func idr(r: ResolvedProcess) -> ResolvedProcess { r }\nexport pure func forge(r: ResolvedProcess) -> ResolvedProcess { { idr(r) | budget: ExplicitMs(999999) } }\n' >"$F"
row g5 'D7: only the resolver builds a result' 'another module updates budget on a call result, the form the review found' 1 'record update of result field `budget`'

printf 'module scripts/gate_forged\nimport src/core/process_limits (ResolvedProcess, ExplicitMs)\npure func idr(r: ResolvedProcess) -> ResolvedProcess { r }\nexport pure func forge(r: ResolvedProcess) -> ResolvedProcess { { idr({ r }) | budget: ExplicitMs(999999) } }\n' >"$F"
row g5.brace 'D7: only the resolver builds a result' 'the same update, with braces inside the base' 1 'record update of result field `budget`'

cat >"$F" <<'AIL'
module scripts/gate_forged
import src/core/process_limits (ResolvedProcess, ProcessResolution, ProcessResolved, ProcessInvalid, SessionLimit, ProcessBudget, SessionDefault)
-- the rule's words, in a comment: { r | budget: x } session_default: effective_ceiling: clamped: requested_ms:
export pure func note() -> string { "{ r | budget: x } session_default: effective_ceiling: clamped: requested_ms:" }
export pure func read_default(p: ProcessResolution) -> Option[SessionLimit] {
  match p {
    ProcessResolved(r) => Some(r.session_default),
    ProcessInvalid(_) => None
  }
}
export pure func read_budget(p: ProcessResolution) -> ProcessBudget {
  match p {
    ProcessResolved(r) => r.budget,
    ProcessInvalid(_) => SessionDefault
  }
}
AIL
sed -i '2i import std/option (Option, Some, None)' "$F"
row g6 'the rule must not over-fire' 'a legal caller: imports the type, matches ProcessResolved(r), reads session_default and budget, names the fields in a comment and a string' 0 ', 0 breaches'

printf 'module scripts/gate_forged\ntype Ctx = { task: string, budget: int }\npure func mk() -> Ctx { { task: "a", budget: 0 } }\nexport pure func f() -> Ctx { { mk() | task: "b", budget: 1 } }\n' >"$F"
row g6.ctx 'the rule must not over-fire' 'an update of another record on a call result, naming budget and a non-result field, the shape of the 16 PureCtx updates in the tree' 0 ', 0 breaches'

printf 'module scripts/gate_forged\nexport pure func lit(a: bool, b: bool) -> {ok: bool, budget: int} { { ok: a || b, budget: 3 } }\nexport pure func blk(a: bool, b: bool) -> int { let ok = a || b; let budget: int = 3; if ok then budget else 0 }\n' >"$F"
row g6.or 'the rule must not over-fire' 'a `||` and then a `budget:` that is a literal label or a let annotation, in the same braces' 0 ', 0 breaches'

printf 'module scripts/gate_forged\nimport src/core/process_limits (ResolvedProcess, ExplicitMs)\npure func idr(r: ResolvedProcess) -> ResolvedProcess { r }\nexport pure func forge(r: ResolvedProcess) -> ResolvedProcess { { idr(r) | task: "t", budget: ExplicitMs(999999) } }\n' >"$F"
row g7 'the exemption rests on the compiler' 'an update of a result naming a non-result field: the checker exempts it, so ailang check must refuse it' 0 ', 0 breaches'
trap - EXIT

clean && echo "tree clean" || { echo "tree dirty"; exit 2; }
echo "commit $COMMIT"
echo "$COMMIT" >"$OUT/commit"
cut -f7 "$TSV" | tail -n +2 | sort | uniq -c
