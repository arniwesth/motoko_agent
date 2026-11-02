#!/usr/bin/env bash
# 041 W2: run the mutants one at a time against `make verify_native_process_tree`.
# Run from the worktree root on a clean tree: mutate.sh <log directory>. Writes mutants.tsv.
# A mutant is killed only when the probe's FAIL line for its named row appears and
# the target exits non-zero. A compile error is recorded as what it is.
set -u
EV=.agent/projects/041_process_execution_timeouts/evidence/W2
OUT=${1:?log directory}
P=scripts/verify_native_process_tree.ail
K=scripts/verify_native_process_sigkill.ail
M=Makefile
clean() { [ -z "$(git status --porcelain -- scripts Makefile)" ]; }
clean || { echo "scripts or Makefile dirty"; exit 2; }
COMMIT=$(git rev-parse HEAD)
TSV=$OUT/mutants.tsv
printf 'id\trule\tedit\texpected_row\tcommit\tred_rows\talso_red\tverdict\n' >"$TSV"

edit() { python3 - "$1" "$2" "$3" <<'PY' || exit 2
import sys
f, old, new = sys.argv[1:]
s = open(f).read()
if s.count(old) != 1: sys.exit("edit matches %d times: %s" % (s.count(old), old))
open(f, 'w').write(s.replace(old, new))
PY
}

probe() { # id: runs the target, leaves the log
  env -u AILANG_FS_SANDBOX "${@:2}" make verify_native_process_tree >"$OUT/$1.log" 2>&1; echo $? >"$OUT/$1.rc"
}

score() { # id rule edit expected
  local id=$1 rule=$2 ed=$3 want=$4 rc red also verdict
  rc=$(cat "$OUT/$id.rc")
  red=$(grep -E '^FAIL: ' "$OUT/$id.log" | sed -E 's/^FAIL: //; s/ — .*//' | paste -sd '|' -)
  also=$(printf '%s\n' "$red" | tr '|' '\n' | grep -vxF "$want" | paste -sd '|' -)
  if ! grep -qE '^elapsed_ms=' "$OUT/$id.log"; then verdict="did not run"
  elif [ "$rc" -ne 0 ] && printf '%s\n' "$red" | tr '|' '\n' | grep -qxF "$want"; then verdict=killed
  else verdict=survived; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$rule" "$ed" "$want" "${COMMIT:0:8}" "${red:-none}" "${also:-none}" "$verdict" >>"$TSV"
  echo "$id: rc=$rc verdict=$verdict red=[${red:-none}]"
  git checkout -q -- scripts Makefile
  clean || { echo "did not restore"; exit 2; }
}

# The unmutated source is green first.
probe base; [ "$(cat "$OUT/base.rc")" = 0 ] && ! grep -qE 'NOT EVALUATED|^FAIL' "$OUT/base.log" \
  && echo "base: green, no NOT EVALUATED" || { echo "base is not green"; exit 2; }

HELD_W='setsid pipes held: marker written'
CLOSED_W='setsid pipes closed: marker written after the return'
HELD_L="setsid pipes held: return latency no earlier than the descendant's exit, no later than limit + WaitDelay"
CLOSED_L='setsid pipes closed: return latency near the limit'
DEADLINE='deadline enforced, the group was killed before 2000ms'

# d1, the plan's named mutant, one per case: assert the marker is absent.
edit $P 'report("setsid pipes held: marker written", fileExists(' 'report("setsid pipes held: marker written", not fileExists('
probe d1.held; score d1.held 'D5 marker written (held)' 'assert the marker is absent' "$HELD_W"
edit $P 'not c.at_return && fileExists(' 'not c.at_return && not fileExists('
probe d1.closed; score d1.closed 'D5 marker written (closed)' 'assert the marker is absent' "$CLOSED_W"
edit $M 'wrote its marker" "$$after" yes' 'wrote its marker" "$$after" no'
probe d1.sigkill; score d1.sigkill 'D5 command survives SIGKILL' 'assert the marker is absent' 'SIGKILL: the command survived and wrote its marker'

# Stubbed exits: the rows must depend on a real exit, not on the assertion alone.
edit $P "setsid sh -c 'sleep 3; printf done > \\\"\${path}_marker\\\"' \${redirect}" "setsid sh -c 'exit 0' \${redirect}"
probe s1.descendant; score s1.descendant 'held return waits for the real exit' 'the descendant exits at once and writes nothing' "$HELD_L"
edit $P 'let results = run_native_batch([call], ".");
  let elapsed = now() - start;
  let at_return' 'let results = [BashExecResult({ id: id, fault: Some({ kind: FaultDeadline(3000), effects: EffectsUnknown }), cmd: "", stdout: "", stderr: "", exit_code: 1, meta: { truncated: false, stdout_bytes: 0, stdout_total_bytes: 0, stderr_bytes: 0, stderr_total_bytes: 0, stdout_sha256: "", stderr_sha256: "" } })];
  let elapsed = now() - start;
  let at_return'
probe s2.canned; score s2.canned 'rows read the world, not the result' 'a canned Timeout result, no command runs' "setsid pipes held: $DEADLINE"
edit $K 'sleep 2; printf survived > \"$PROBE_SIGKILL_DIR/marker\"' 'sleep 2'
probe s3.sigkill-stub; score s3.sigkill-stub 'SIGKILL marker comes from the command' 'the command exits without a marker' 'SIGKILL: the command survived and wrote its marker'
edit $M 'kill -9 "$$pid" 2>/dev/null; wait' 'kill -0 "$$pid" 2>/dev/null; wait'
probe s4.nosignal; score s4.nosignal 'the signal is really sent' 'kill -0 in place of kill -9, the runtime exits normally' 'SIGKILL: the runtime died of the signal'

# A20: the deadline and the return latency move independently.
edit $P "(printf up > '\${path}_group_up'; sleep 2; printf late > '\${path}_group_late') &" "setsid sh -c 'printf up > \\\"\${path}_group_up\\\"; sleep 2; printf late > \\\"\${path}_group_late\\\"' \${redirect} &"
probe a1.deadline; score a1.deadline 'A20 deadline row alone' 'the group writer escapes the kill; latency must stay green' "setsid pipes held: $DEADLINE"
edit $P '"${root}/closed", "</dev/null >/dev/null 2>&1"' '"${root}/closed", ""'
probe a2.closed-holds; score a2.closed-holds 'A20 closed latency row alone' 'the closed case keeps the pipes; deadline must stay green' "$CLOSED_L"
edit $P 'run_detached("held", "${root}/held", "")' 'run_detached("held", "${root}/held", "</dev/null >/dev/null 2>&1")'
probe a3.held-closes; score a3.held-closes 'A20 held latency row alone' 'the held case closes the pipes; deadline must stay green' "$HELD_L"

# The existing row keeps its meaning: it would see the window if the window reached it.
edit $P '    let elapsed = now() - start;
    let present' '    let present'
edit $P '    let _ = sleep(3500);' '    let _ = sleep(3500);
    let elapsed = now() - start;'
probe e1.window; score e1.window 'elapsed < 4000 is taken before the window' 'take elapsed after the window' 'deadline returns near the wall, not wall + WaitDelay'

# The guard: with setsid off PATH the rows print NOT EVALUATED and the target passes.
SHADOW=$(mktemp -d)
for d in /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin "$HOME/.local/bin"; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do b=${f##*/}; [ "$b" = setsid ] || [ -e "$SHADOW/$b" ] || ln -s "$f" "$SHADOW/$b"; done
done
probe g1.no-setsid PATH="$SHADOW"
echo "g1.no-setsid (survival, must pass): rc=$(cat "$OUT/g1.no-setsid.rc") not_evaluated_lines=$(grep -c 'NOT EVALUATED' "$OUT/g1.no-setsid.log") fail_lines=$(grep -c '^FAIL' "$OUT/g1.no-setsid.log")"
if [ "$(cat "$OUT/g1.no-setsid.rc")" = 0 ] && [ "$(grep -c 'NOT EVALUATED' "$OUT/g1.no-setsid.log")" = 2 ]; then v=passed; else v=failed; fi
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' g1.no-setsid 'NOT EVALUATED does not fail (survival, not a mutant)' 'setsid off PATH via a shadow directory; source unchanged' 'none' "${COMMIT:0:8}" "$(grep -E '^FAIL: ' "$OUT/g1.no-setsid.log" | sed -E 's/^FAIL: //; s/ — .*//' | paste -sd '|' -)" none "$v" >>"$TSV"
edit $P 'Ok(out) => out.exitCode == 0,' 'Ok(out) => true,'
probe g2.no-guard PATH="$SHADOW"; score g2.no-guard 'the guard is what keeps a host without setsid green' 'the guard always answers present; setsid off PATH' "$HELD_L"
rm -rf "$SHADOW"

clean && echo "tree clean" || { echo "tree dirty"; exit 2; }
echo "commit $COMMIT"
echo "$COMMIT" >"$OUT/commit"
