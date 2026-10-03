#!/usr/bin/env bash
# Each geometry check must flag its seeded defect and nothing else, and the example film must
# come out clean. Draws nothing: about fifteen seconds.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
media=$(mktemp -d)
trap 'rm -rf "$media"' EXIT

"$here/explainer" lint "$here/examples/defects.py" --media "$media/defects" --json \
  >"$media/defects.json" || [ $? = 2 ]
"$here/explainer" lint "$here/examples/minimal.py" --media "$media/minimal" --json \
  >"$media/minimal.json"

python3 - "$media/defects.json" "$media/minimal.json" <<'PY'
import json, sys
defects, minimal = (json.load(open(p)) for p in sys.argv[1:3])
expected = {"Clean": [], "OffFrame": ["off_frame"], "NearEdge": ["near_edge"],
            "TextOverlap": ["text_overlap"], "CaptionOverlap": ["caption_overlap"],
            "SmallText": ["small_text"], "CaptionCut": ["caption_cut"]}
found = {name: [] for name in expected}
for f in defects["lint"]["findings"]:
    found[f["scene"]].append(f["kind"])
bad = {name: (found[name], kinds) for name, kinds in expected.items()
       if set(found[name]) != set(kinds)}
for name, (got, want) in bad.items():
    print(f"FAIL {name}: lint found {got}, expected {want}")
if minimal["lint"]["findings"] or not minimal["ok"]:
    bad["minimal"] = True
    print(f"FAIL minimal.py: expected no findings, got {minimal['lint']['findings']}")
if defects["ok"]:
    bad["ok"] = True
    print("FAIL defects.py: the report says ok although it holds errors")
print("selftest: " + ("FAILED" if bad else
      f"ok, {len(expected) - 1} seeded defects each flagged as its own kind, 2 clean scenes clean"))
sys.exit(1 if bad else 0)
PY
