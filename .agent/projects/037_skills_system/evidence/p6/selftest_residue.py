#!/usr/bin/env python3
"""037 P6 evidence: reduce each failure line of `ext_hook_scope_selftest` to the
extensions on which the pin and the tool disagree, at the four points P6 has a
log for. The lines print two whole dictionaries; the reading that matters is
which keys differ.

    python3 selftest_residue.py        (from the worktree root)
"""
import ast
import re

HERE = ".agent/projects/037_skills_system/evidence/p6"
RUNS = (
    ("P0 baseline, an export of 501cd879", f"{HERE}/baseline_export/ext_hook_scope_selftest.log"),
    ("before P6, 0f4724de", f"{HERE}/gates/head_before/ext_hook_scope_selftest.log"),
    ("the repair, c708d2cc", f"{HERE}/gates/repair/ext_hook_scope_selftest.log"),
    ("the re-pin, 7e6f6ab6", f"{HERE}/gates/repin/ext_hook_scope_selftest.log"),
)
LINE = re.compile(r"FAIL (YIELD[^:]*): expected (\{.*?\}|\[.*?\]|\d+)(?: extensions)?, "
                  r"(?:derived|got) (\{.*?\}|\[.*?\]|\d+)")

for tag, path in RUNS:
    print("==", tag)
    for line in open(path):
        line = line.strip()
        if not line.startswith("FAIL"):
            continue
        m = LINE.match(line)
        if not m:
            print("    (unparsed)", line[:160])
            continue
        name, want, got = m.group(1), ast.literal_eval(m.group(2)), ast.literal_eval(m.group(3))
        if isinstance(want, dict):
            keys = sorted(k for k in set(want) | set(got)
                          if want.get(k, "<absent>") != got.get(k, "<absent>"))
            pairs = [(k, want.get(k, "<absent>"), got.get(k, "<absent>")) for k in keys]
            print(f"    {name}: (extension, pinned, derived) {pairs}")
        elif isinstance(want, list):
            print(f"    {name}: in one list and not the other {sorted(set(want) ^ set(got))}")
        else:
            print(f"    {name}: pinned {want}, derived {got}")
