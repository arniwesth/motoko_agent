#!/usr/bin/env bash
# src/eval/journal/testdata/m15_k_rows.sh
#
# PLAN-004 M15's K-rows (P1.9b-v2, the catching check's half): the candidate
# rows whose family half P1.9a landed (scripts/eval/test_candidate.py's
# PERMITTED_EDIT, TOOL_PHASE_EDIT, OUTSIDE_SPANS_EDIT — the same edits, byte
# for byte), each run as a REAL candidate build through K1–K7, with the
# first finding and its typed location printed as a `KROW` line.
#
#   bash src/eval/journal/testdata/m15_k_rows.sh <scratch-dir>
#
# 1. P's build (this working tree) admits m3_selector_end and writes the
#    entry: program.artifact (P1.8's codec) and entry.json
#    (candidate_checks_run.entry_json).
# 2. For each case a fresh tree is exported from HEAD into the scratch dir,
#    the evaluator paths (src/eval/journal) and ailang.lock are copied from
#    this working tree (E and A's lock), the case's ONE source edit is
#    applied, and `candidate_checks_live_test.ail` runs there in
#    EVAL_K_MODE=candidate: C's src/core is the edited one.
#
# This is NOT candidate.py's assembly (no guard, no K0, no effective lock):
# it exercises K1–K7 against a genuinely different compiled src/core. The
# runner's candidate mode still stops after K0 (P1.9a); wiring K1–K7 into it
# is outside this part's write scope.
#
# Cases:
#   clean              no edit (C = P across processes)       -> reproduced
#   path_permitted     src/core/phase_vocab.ail  ["m-end;"] -> ["m-end!"]
#                      (M15 InadmissibleCandidate path; also the intent
#                      row, which uses the same edit under a resource-only
#                      record)
#   evaluator_touched  src/core/tool_phase.ail MOTOKO_TOOL_TIMEOUT_MS -> _MX
#   protected_region   src/core/ports.ail has_key: a comment line inside an
#                      unlisted callee, outside every protected span (P1.9a's
#                      fixture: it changes no recorder input)
#   closure_search     the search the row asks for: src/core/ports.ail
#                      tool_call_json — an unlisted callee (manifest-A.json:
#                      tool_calls_json -> tool_call_json) outside every span —
#                      emits its keys in another order, which changes the
#                      provider outcome the recorder writes
#
# Each edited tree is first run through E's protected checker
# (tools/eval_protected/protected.py check, manifest-A.json): `KPROT`.
#
# Writes only under <scratch-dir>. Synthetic fixtures only (§0.6).
set -euo pipefail

WORK=${1:?usage: m15_k_rows.sh <scratch-dir>}
ROOT=$(git rev-parse --show-toplevel)
CAPS=IO,Env,FS,AI,Process,Net,SharedMem,Clock,Stream,Trace,Rand
TEST=src/eval/journal/candidate_checks_live_test.ail

mkdir -p "$WORK/entry"
(cd "$ROOT" && EVAL_K_MODE=entry EVAL_K_DIR="$WORK/entry" \
   ailang run --caps "$CAPS" --ai-stub --entry main "$TEST" </dev/null) | grep '^KENTRY'

edit() {  # edit <tree> <file> <old> <new>
  python3 - "$1/$2" "$3" "$4" <<'EOF'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
assert s.count(old) >= 1, (path, old)
open(path, "w").write(s.replace(old, new, 1))
EOF
}

run_case() {  # run_case <name>
  local name=$1 tree="$WORK/tree-$1"
  rm -rf "$tree"
  mkdir -p "$tree"
  git -C "$ROOT" archive HEAD | tar -x -C "$tree"
  rm -rf "$tree/src/eval/journal"
  mkdir -p "$tree/src/eval/journal"
  (cd "$ROOT/src/eval/journal" && tar --exclude=__pycache__ --exclude=.ailang -cf - .) | tar -x -C "$tree/src/eval/journal"
  cp "$ROOT/ailang.lock" "$tree/ailang.lock"
  case "$name" in
    clean) ;;
    path_permitted) edit "$tree" src/core/phase_vocab.ail '["m-end;"]' '["m-end!"]' ;;
    evaluator_touched) edit "$tree" src/core/tool_phase.ail MOTOKO_TOOL_TIMEOUT_MS MOTOKO_TOOL_TIMEOUT_MX ;;
    protected_region) edit "$tree" src/core/ports.ail \
      'pure func has_key(obj: Json, key: string) -> bool {' \
      $'pure func has_key(obj: Json, key: string) -> bool {\n  -- fx: outside every protected span' ;;
    closure_search) edit "$tree" src/core/ports.ail \
      'jo([kv("id", js(c.id)), kv("name", js(c.name)), kv("arguments", js(c.arguments))])' \
      'jo([kv("name", js(c.name)), kv("id", js(c.id)), kv("arguments", js(c.arguments))])' ;;
    *) echo "unknown case $name" >&2; return 2 ;;
  esac
  local prot
  prot=$(python3 "$ROOT/tools/eval_protected/protected.py" check --manifest "$ROOT/tools/eval_protected/manifest-A.json" \
         --tree "$tree" --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["findings"]))') || true
  echo "KPROT $name findings=$prot"
  (cd "$tree" && EVAL_K_MODE=candidate EVAL_K_DIR="$WORK/entry" EVAL_K_CASE="$name" \
   ailang run --caps "$CAPS" --ai-stub --entry main "$TEST" </dev/null) \
    | grep -E '^(KROW|KALL|CANDIDATE|ENVELOPE (findings|score|exhausted_markers|marker_check|identity_evidence))'
}

for c in ${M15_K_CASES:-clean path_permitted evaluator_touched protected_region closure_search}; do
  run_case "$c"
done
