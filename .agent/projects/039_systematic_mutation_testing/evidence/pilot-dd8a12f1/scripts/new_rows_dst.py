#!/usr/bin/env python3
"""039 random-mutant pilot, follow-up F2: a reading aid, NOT a scorer. Written after the F2 sweeps.

    new_rows_dst.py <evidence dir> <id>...

Lists the failing-looking lines (a cross, FAIL, a runtime error) in runs/dst/<id>/out.txt that do not
occur in runs/dst/C-base/out.txt after normalising digits and /tmp paths. Each is tagged with the
make target whose `*** [Makefile:N: <target>]` line follows it (make dst syncs output per target).
The readings in mutants-dst-results.md are made by hand from these rows and the lines around them;
score_dst.py, fixed before F2, gives the ordinary reading.
"""
import re, sys
E = sys.argv[1]
FAIL = re.compile(r"\*\*\* \[Makefile:\d+: ([^\]]+)\]")
BAD = re.compile(r"✗|\bFAIL\b|FAILED|RT0\d\d|panic|Error: execution failed")
def norm(l):
    l = re.sub(r"\x1b\[[0-9;]*m", "", l)
    l = re.sub(r"/tmp/[\w./-]+", "/tmp/X", l)
    l = re.sub(r"\d+(\.\d+)?", "N", l)
    return l.strip()
base = {norm(l) for l in open(f"{E}/runs/dst/C-base/out.txt", encoding="utf-8", errors="replace") if BAD.search(l)}
for m in sys.argv[2:]:
    lines = open(f"{E}/runs/dst/{m}/out.txt", encoding="utf-8", errors="replace").read().splitlines()
    print(f"######## {m}")
    for i, l in enumerate(lines):
        if BAD.search(l) and norm(l) not in base and not FAIL.search(l) and "─── make dst" not in l:
            tgt = "?"
            for later in lines[i + 1:]:
                f = FAIL.search(later)
                if f: tgt = f.group(1); break
            print(f"  [{tgt}] {re.sub(chr(27)+r'\[[0-9;]*m','',l).strip()[:200]}")
