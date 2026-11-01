#!/usr/bin/env bash
# 041 W3: run the mutants one at a time against the cancellation witness and its twin.
# Run from the worktree root on a clean tree, with src/tui's dependencies installed:
#   mutate.sh <log directory>. Writes mutants.tsv and commit there.
#
# Unlike an ordinary kill, the witness is `it.failing`. A witness row "stops failing" when Jest
# reports it red with "Failing test passed even though it was supposed to fail". A mutant counts as
# killed only when each row's status is exactly what its row names: a compile error, or a suite that
# did not run, is recorded as what it is.
set -u
OUT=${1:?log directory}
T=src/tui/src/runtime-process.cancel.test.ts
S=scripts/verify_runtime_cancel_process_tree.sh
clean() { [ -z "$(git status --porcelain -- src/tui/src scripts)" ]; }
clean || { echo "src/tui/src or scripts dirty"; exit 2; }
COMMIT=$(git rev-parse HEAD)
TSV=$OUT/mutants.tsv
printf 'id\trule\tedit\texpected\tcommit\tobserved\tverdict\n' >"$TSV"

edit() { python3 - "$1" "$2" "$3" <<'PY' || exit 2
import sys
f, old, new = sys.argv[1:]
s = open(f).read()
if s.count(old) != 1: sys.exit("edit matches %d times: %s" % (s.count(old), old))
open(f, 'w').write(s.replace(old, new))
PY
}

restore() { git checkout -q -- src/tui/src scripts; clean || { echo "did not restore"; exit 2; }; }

# Prints run/command/descendant, each passed, failed or stopped-failing (a witness row that passed).
jest_rows() { # id
  (cd src/tui && bun node_modules/.bin/jest --testPathPattern='src/runtime-process\.cancel\.test\.ts' \
    --json --outputFile="$OUT/$1.json" >"$OUT/$1.log" 2>&1); echo $? >"$OUT/$1.rc"
  python3 - "$OUT/$1.json" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("no-json"); sys.exit()
rows = {}
for t in (t for r in d["testResults"] for t in r["assertionResults"]):
    key = "run" if "really ran" in t["title"] else "descendant" if "descendant" in t["title"] else "command"
    # Under bun the printed failure and failureMessages are blank; failureDetails has the sentence.
    msg = " ".join(str(x.get("message", "")) for x in t.get("failureDetails") or [] if isinstance(x, dict))
    s = t["status"]
    if s == "failed" and "Failing test passed" in msg: s = "stopped-failing"
    rows[key] = s
print(",".join(f"{k}={rows.get(k, 'absent')}" for k in ("run", "command", "descendant")) or "no-rows")
PY
}

record() { # id rule edit expected observed
  local v=survived
  [ "$5" = "$4" ] && v=killed
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "${COMMIT:0:8}" "$5" "$v" >>"$TSV"
  echo "$1: expected=[$4] observed=[$5] verdict=$v"
}

jest_mutant() { # id rule edit expected: the mutation is already applied
  local got; got="$(jest_rows "$1")"
  record "$1" "$2" "$3" "$4" "rc=$(cat "$OUT/$1.rc") $got"
  restore
}

twin_mutant() { # id rule edit expected-rc: the mutation is already applied
  bash "$S" >"$OUT/$1.log" 2>&1; local rc=$?
  record "$1" "$2" "$3" "rc=$4" "rc=$rc"
  restore
}

# The unmutated tree first: the witness rows fail as expected, and the twin reproduces.
got="$(jest_rows base)"
[ "$(cat "$OUT/base.rc")" = 0 ] && [ "$got" = "run=passed,command=passed,descendant=passed" ] \
  && echo "base jest: green, witness rows failing as expected" || { echo "base jest: rc=$(cat "$OUT/base.rc") $got"; exit 2; }
bash "$S" >"$OUT/base-twin.log" 2>&1; rc=$?
[ "$rc" = 1 ] && echo "base twin: rc=1, reproduced" || { echo "base twin: rc=$rc"; exit 2; }

CMD_WRITE="printf late > '\${commandPath}'"
DESC_WRITE="printf late > '\${descendantPath}'"
GREEN=run=passed
BOTH="rc=1 $GREEN,command=stopped-failing,descendant=stopped-failing"

# c1, the plan's named mutant, and one case per marker: the expected failure stops failing.
edit "$T" "$CMD_WRITE" ":"; edit "$T" "$DESC_WRITE" ":"
jest_mutant c1 'the witness observes the markers (plan: mutant c1)' 'the command and descendant skip writing their markers; the started file stays' "$BOTH"
edit "$T" "$CMD_WRITE" ":"
jest_mutant c1.command 'the command row reads the command marker' 'the command skips its marker' "rc=1 $GREEN,command=stopped-failing,descendant=passed"
edit "$T" "$DESC_WRITE" ":"
jest_mutant c1.descendant 'the descendant row reads the descendant marker' 'the descendant skips its marker' "rc=1 $GREEN,command=passed,descendant=stopped-failing"

# The suite turns red when the behaviour changes. Simulated in the test alone, by stopping the tree
# just before the helper runs; runtime-process.ts and interruptRuntime are not edited.
edit "$T" 'observed.action = interruptRuntime(running);' 'const { execSync } = await import("child_process");
    execSync(`for c in $(pgrep -P ${(running as any).proc.pid}); do kill -KILL -- -$c; done`, { shell: "/bin/bash" });
    observed.action = interruptRuntime(running);'
jest_mutant f1 'the suite turns red when the tree is stopped (simulated in the test)' 'kill the command group from the test, then call the helper' "$BOTH"

# The ordinary row keeps the expected failures from absorbing a broken experiment.
edit "$T" 'observed.action = interruptRuntime(running);' 'observed.action = "kill";'
jest_mutant h1 'the signal is really sent' 'no signal; the deadline ends the command and the run finishes' "rc=1 run=failed,command=stopped-failing,descendant=stopped-failing"
edit "$T" 'await experiment().catch(' 'await Promise.reject(new Error("no experiment")).catch('
jest_mutant h2 'an experiment that did not run is not an expected failure' 'the experiment never runs' "rc=1 run=failed,command=stopped-failing,descendant=stopped-failing"
edit "$T" 'exec ailang "$@"' 'exec /nonexistent/ailang "$@"'
jest_mutant h3 'a runtime that cannot start is not an expected failure' 'the wrapper execs a missing binary' "rc=1 run=failed,command=stopped-failing,descendant=stopped-failing"

# The twin.
edit "$S" 'printf late > \"\$PROBE_DIR/descendant\"' ':'; edit "$S" 'printf late > \"\$PROBE_DIR/command\"' ':'
twin_mutant t1 'the twin observes the markers' 'the command and descendant skip writing their markers' 0
edit "$S" 'kill "-$signal" "$pid"' 'kill -0 "$pid"'
twin_mutant t2 'the twin really sends the signal' 'kill -0 in place of the signal' 2

clean && echo "tree clean" || { echo "tree dirty"; exit 2; }
echo "commit $COMMIT"
echo "$COMMIT" >"$OUT/commit"
