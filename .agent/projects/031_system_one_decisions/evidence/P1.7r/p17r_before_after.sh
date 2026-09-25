#!/usr/bin/env bash
# 031 PLAN-001 P1.7r: the BEFORE/AFTER of `derive.py --json` for both classifiers, against
# COMMITTED HEAD. Run from the primary repo root; writes json/ and BEFORE-AFTER.md beside this script.
#
#   before: a fresh `git clone --shared` of this checkout (HEAD, nothing of the working tree),
#           lock regenerated there (the ailang.lock trap), both tools run as committed;
#   after:  P1.7r's paths (tools/ext_call_inventory, tools/ext_ambient_inventory, this evidence
#           dir) copied over the same clone, both tools run again.
# `ext_ambient_inventory/derive.py --json` provisions (18 `ailang check`s in the clone) so its
# closure verdicts measure the tree, not a cold cache.
set -uo pipefail
E=.agent/projects/031_system_one_decisions/evidence/P1.7r
[ -f "$E/p17r_selftest.sh" ] || { echo "p17r_before_after: run from the repo root" >&2; exit 2; }
PATHS="tools/ext_call_inventory tools/ext_ambient_inventory $E"
R=$(pwd); J="$R/$E/json"; mkdir -p "$J"
W=$(mktemp -d /workspaces/p17r-ba.XXXXXX); trap 'rm -rf "$W"' EXIT
git clone --shared --quiet "$(pwd)" "$W" || { echo "p17r_before_after: clone failed" >&2; exit 2; }
head=$(git -C "$W" rev-parse --short HEAD)
( cd "$W" && rm -f ailang.lock && ailang lock > lock.log 2>&1 ) || { echo "p17r_before_after: lock failed" >&2; exit 2; }
run() { # $1 before|after
  ( cd "$W" && python3 tools/ext_call_inventory/derive.py --json > "$J/c2-$1.json" 2> "$J/c2-$1.stderr"; echo "c2 $1 exit $?"
    python3 tools/ext_ambient_inventory/derive.py --json > "$J/c3-$1.json" 2> "$J/c3-$1.stderr"; echo "c3 $1 exit $?" )
}
echo "p17r_before_after: HEAD $head"
run before
for p in $PATHS; do rm -rf "$W/$p"; mkdir -p "$W/$(dirname "$p")"; cp -a "$R/$p" "$W/$p"; done
find "$W/tools" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null
run after
python3 - "$J" "$head" > "$R/$E/BEFORE-AFTER.md" <<'PY'
import json, sys
from collections import Counter
J, head = sys.argv[1], sys.argv[2]
c2b, c2a = json.load(open(f"{J}/c2-before.json")), json.load(open(f"{J}/c2-after.json"))
c3b, c3a = json.load(open(f"{J}/c3-before.json")), json.load(open(f"{J}/c3-after.json"))
print(f"# P1.7r — `derive.py --json` before/after, both classifiers, at committed HEAD `{head}` (fresh clone, lock regenerated)\n")
print("## classifier 2 — `tools/ext_call_inventory/derive.py --json` (`make ext_call_inventory`)\n")
print("| key | before | after |\n|---|---|---|")
print(f"| exit | 1 | 0 |")
for k in ("classifier_2_set", "unrouted_fields"): print(f"| `{k}` | {c2b[k]} | {c2a[k]} |")
print(f"| `member_call_sites` | {len(c2b['member_call_sites'])} | {len(c2a['member_call_sites'])} |")
print(f"| `non_member_call_sites` | {len(c2b['non_member_call_sites'])} | {len(c2a['non_member_call_sites'])} ({dict(Counter(o.get('via','direct') for o in c2a['non_member_call_sites']))}) |")
print(f"| `unresolved` | **{len(c2b['unresolved'])}** ({dict(Counter(o['file'] for o in c2b['unresolved']))}) | **{len(c2a['unresolved'])}** |")
print(f"| `port_views` | absent | {', '.join(f'{k} ({len(v['fields'])})' for k, v in c2a['port_views'].items())} |")
print(f"| `port_view_projections` | absent | {len(c2a['port_view_projections'])} ({dict(Counter(o['file'] for o in c2a['port_view_projections']))}) |")
print("\n## classifier 3 — `tools/ext_ambient_inventory/derive.py --json` (`make ext_ambient_inventory`)\n")
print(f"| | before | after |\n|---|---|---|")
print(f"| exit | 1 | 0 |")
print(f"| verdicts | {dict(Counter(x['verdict'] for x in c3b['extensions'].values()))} | {dict(Counter(x['verdict'] for x in c3a['extensions'].values()))} |")
print(f"| PORT-MEDIATED | {sorted(e for e, x in c3b['extensions'].items() if x['verdict']=='PORT-MEDIATED')} | {sorted(e for e, x in c3a['extensions'].items() if x['verdict']=='PORT-MEDIATED')} |")
print(f"| cache precondition | {len(c3b['std_modules_resolved'])}/{len(c3b['std_modules_needed'])} | {len(c3a['std_modules_resolved'])}/{len(c3a['std_modules_needed'])} |")
print("\n| extension | before | unresolved receivers | calls | after | unresolved receivers | calls | projections |\n|---|---|--:|--:|---|--:|--:|--:|")
for e in sorted(c3a["extensions"]):
    x, y = c3b["extensions"][e], c3a["extensions"][e]
    print(f"| {e} | {x['verdict']} | {x['unresolved_receivers']} | {x['ext_ports_calls']} | {y['verdict']} | {y['unresolved_receivers']} | {y['ext_ports_calls']} | {y.get('ext_ports_projections', 0)} |")
PY
echo "p17r_before_after: wrote $E/BEFORE-AFTER.md and $J/"
