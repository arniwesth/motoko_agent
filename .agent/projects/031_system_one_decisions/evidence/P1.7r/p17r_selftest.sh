#!/usr/bin/env bash
# 031 PLAN-001 P1.7r: run one of the three self-tests from a repo root -- the primary checkout,
# a HEAD workspace (p17r_headws.sh) or a mutgate throwaway (p17r_mutgate.sh) -- and score it
# for P1.7r's files.
#
#   p17r_selftest.sh hook      `make ext_hook_scope_selftest`'s command; GREEN iff exit 0
#   p17r_selftest.sh ambient   `make ext_ambient_inventory_selftest`'s command; GREEN iff exit 0
#   p17r_selftest.sh call      `make ext_call_inventory_selftest`'s command; GREEN iff exit 0
#   p17r_selftest.sh c2        classifier 2 over the tree (`make ext_call_inventory`); GREEN iff
#                              exit 0 (0 unresolved)
#   P17R_RAW=<file>            when set, the self-test's full output is copied there (evidence)
#   p17r_selftest.sh check     AILANG_RELAX_MODULES=1 `ailang check` of each of the 17 fixtures
#                              against THIS tree's ABI package. Informational: several fixtures
#                              are uncompilable BY DESIGN and the self-test never asserts the
#                              compile; every verdict is printed, nothing is scored.
#
# THE LOCK TRAP. A tracked ailang.lock pins path dependencies to the primary checkout's
# absolute path, so `ailang check` anywhere else resolves the primary's packages. Anywhere but
# the primary this regenerates the lock ONCE (`ailang lock`; offline, the dependencies are all
# path dependencies), so every compile here resolves this tree's own packages -- what P1.2's
# workspaces did by construction.
#
# SCORING: every mode is GREEN iff its self-test exits 0 -- no exclusions. (An earlier revision of
# this harness excluded ONE named failure line, the closure verdict moved by classifier 2's blindness
# to the 8.0 views; P1.7r then taught classifier 2 the views in the same commit -- README.md §4 --
# and the exclusion went with the residual. Anything the harness would have to exclude is red.)
#
# No `cmd | grep -q` under pipefail anywhere: output goes to a file first.
set -uo pipefail
mode="${1:-}"
[ -f ailang.toml ] && [ -d tools/ext_ambient_inventory ] || { echo "p17r: run from a repo root" >&2; exit 2; }
PRIMARY=/workspaces/motoko_agent
if [ "$(pwd -P)" != "$PRIMARY" ] && [ ! -f .p17r-lock-regenerated ]; then
  rm -f ailang.lock
  ailang lock > .p17r-lock.log 2>&1 || { tail -5 .p17r-lock.log; echo "p17r: ailang lock FAILED here"; exit 2; }
  n=$(grep -c "$PRIMARY/" ailang.lock || true)
  [ "$n" = 0 ] || { echo "p17r: the regenerated lock still names the primary ($n)"; exit 2; }
  touch .p17r-lock-regenerated
  echo "p17r: lock regenerated for $(pwd -P) (lock-free of the primary)"
fi
strip() { sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g'; }
FX=tools/ext_ambient_inventory/fixtures/hook_scope
OUT=$(mktemp "${TMPDIR:-/tmp}/p17r.XXXXXX"); trap 'rm -f "$OUT" "$OUT.fails"' EXIT

case "$mode" in
  hook)    python3 tools/ext_ambient_inventory/derive.py --hook-scope-selftest > "$OUT" 2>&1; rc=$? ;;
  ambient) python3 tools/ext_ambient_inventory/derive.py --self-test > "$OUT" 2>&1; rc=$? ;;
  call)    python3 tools/ext_call_inventory/derive.py --self-test > "$OUT" 2>&1; rc=$? ;;
  c2)      python3 tools/ext_call_inventory/derive.py > "$OUT" 2>&1; rc=$? ;;
  check)
    export AILANG_RELAX_MODULES=1
    for f in "$FX"/*.ail; do
      ailang check "$f" > "$OUT" 2>&1; rc=$?
      if [ $rc -eq 0 ]; then echo "p17r: check $(basename "$f") clean"
      else first=$(strip < "$OUT" | grep -vE 'MOD010 \(relaxed\)|relax-modules' | grep -m1 -E 'Error|error|TC0|EFF|PAR_|LDR0|Missing|cannot|not found' | cut -c1-600); echo "p17r: check $(basename "$f") exit $rc: ${first}"; fi
    done; exit 0 ;;
  *) echo "usage: $0 hook|ambient|call|c2|check" >&2; exit 2 ;;
esac

[ -n "${P17R_RAW:-}" ] && cp "$OUT" "$P17R_RAW"
[ -n "${P17R_RAW:-}" ] && cp "$OUT" "$P17R_RAW"
grep -E '^  FAIL |^UNRESOLVED \(' "$OUT" > "$OUT.fails" || true
n_ok=$(grep -c '^  ok  ' "$OUT" || true); n_fail=$(wc -l < "$OUT.fails")
grep -E 'self-test: [0-9]+ failure|^UNRESOLVED \(|^ExtPorts VIEWS|^port-view projections' "$OUT"
if [ $rc -eq 0 ]; then echo "p17r: $mode GREEN (exit 0; $n_ok ok rows)"; exit 0; fi
echo "p17r: $mode RED (exit $rc; $n_fail failure line(s)):"
cat "$OUT.fails"
exit 1
