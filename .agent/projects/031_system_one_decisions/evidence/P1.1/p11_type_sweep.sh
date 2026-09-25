#!/usr/bin/env bash
# 031 P1.1 (attempt 2): the TYPE-DRIVEN sweep. `ailang check` every tracked .ail
# under one tree in the P1.1 workspace and record, per file, ok / FAIL and the
# first error line. Run from a repo root:
#   p11_type_sweep.sh core      -> TYPE-SWEEP-core.tsv    (src/core, plain check)
#   p11_type_sweep.sh scripts   -> TYPE-SWEEP-scripts.tsv (P11_RELAX=1)
#   p11_type_sweep.sh tools     -> TYPE-SWEEP-tools.tsv   (P11_RELAX=1)
# The name search (ExtCtx / ExtEntry / register_with_config) misses an INLINE
# context literal (src/core/rpc.ail:152 at attempt 1); the type checker does not.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.1
case "${1:-}" in
  core)    glob='src/core/**/*.ail src/core/*.ail'; relax="";;
  scripts) glob='scripts/**/*.ail scripts/*.ail';   relax=1;;
  tools)   glob='tools/**/*.ail tools/*.ail';       relax=1;;
  *) echo "usage: $0 core|scripts|tools" >&2; exit 2;;
esac
# shellcheck disable=SC2086
mapfile -t files < <(git ls-files -- $glob | sort -u)
out="$E/TYPE-SWEEP-$1.tsv"; log="$E/TYPE-SWEEP-$1.log"
printf 'file\tresult\tfirst_error\n' > "$out"
P11_RELAX="${relax}" bash "$E/p11_core_check.sh" check "${files[@]}" > "$log" 2>&1
grep -E '^p11: check ' "$log" | while IFS= read -r l; do
  f=$(sed -E 's/^p11: check ([^ ]+) .*/\1/' <<<"$l")
  if [[ "$l" == *" ok" ]]; then printf '%s\tok\t\n' "$f"
  else printf '%s\tFAIL\t%s\n' "$f" "$(sed -E 's/^p11: check [^ ]+ FAILED \(exit [0-9]+\): ?//' <<<"$l" | tr '\t' ' ')"; fi
done >> "$out"
ok=$(awk -F'\t' 'NR>1 && $2=="ok"' "$out" | wc -l); n=$(awk 'NR>1' "$out" | wc -l)
echo "p11 type sweep $1: $ok/$n ok (relax=${relax:-0}); $out"
