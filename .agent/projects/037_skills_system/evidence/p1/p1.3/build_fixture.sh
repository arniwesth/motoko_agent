#!/usr/bin/env bash
# 037 P1.3: build a fixture TEMPLATE. P1.2's builder, then the two skills the M2
# task set needs that P1.2's fixture lacks (herdr, observer), then the profile
# edits a row asks for. Only the fixture's own copy of the profile is edited;
# the tree's .motoko/config/skills_proto is not touched. Run from the worktree root.
#   build_fixture.sh <dir> [key=value ...]
#     max_steps=N          agent.max_steps
#     context_limit=N      agent.context_limit
#     model=ID             agent.model
#     order=a,b,c          extensions.order
#     extra_skills=0       skip herdr and observer (P1.2's four skills only)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FX="$1"; shift
rm -rf "$FX"
"$HERE/../p1.2/build_fixture.sh" "$FX" > /dev/null
EXTRA=1
for kv in "$@"; do [ "$kv" = "extra_skills=0" ] && EXTRA=0; done
if [ "$EXTRA" = 1 ]; then
  for s in herdr observer; do cp -r ".claude/skills/$s" "$FX/.motoko/skills/$s"; done
fi
python3 - "$FX/.motoko/config/skills_proto/config.json" "$@" <<'PY'
import json, sys
p = sys.argv[1]
c = json.load(open(p))
for kv in sys.argv[2:]:
    k, v = kv.split("=", 1)
    if k == "max_steps": c["agent"]["max_steps"] = int(v)
    elif k == "context_limit": c["agent"]["context_limit"] = int(v)
    elif k == "model": c["agent"]["model"] = v
    elif k == "order": c["extensions"]["order"] = v.split(",")
    elif k == "extra_skills": pass
    else: sys.exit("unknown key " + k)
json.dump(c, open(p, "w"), indent=2)
PY
echo "fixture template at $FX: skills $(ls "$FX/.motoko/skills" | grep -v README | tr '\n' ' ')"
