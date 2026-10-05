#!/usr/bin/env python3
"""037 P6 evidence: compare one gate-log directory with another, line by line.

    python3 compare_logs.py <dir A> <dir B> [gate ...]

Both sides are normalised the way P2 and P5 normalised theirs before reading
them: colour codes removed; durations, temp-file names, the herdr pane id and
the source revision replaced; the `exit=` line and the lock-warning lines
dropped. For each gate it prints the two exit codes and a unified diff of what
is left, or `identical`. It decides nothing: the reading is in GATES.tsv.
"""
import difflib
import re
import sys
from pathlib import Path

ANSI = re.compile(r"\x1b\[[0-9;]*m")
SUBS = [
    (re.compile(r"\b\d+(\.\d+)?(ms|µs|s)\b"), "<dur>"),
    (re.compile(r"\(\d+(\.\d+)?s\)"), "(<dur>)"),
    (re.compile(r"/tmp/tmp\.[A-Za-z0-9]+"), "/tmp/tmp.<x>"),
    (re.compile(r"\b[0-9a-f]{40}\b"), "<sha>"),
    (re.compile(r"\bw[0-9A-Za-z]+:p[0-9A-Za-z]+\b"), "<pane>"),
    (re.compile(r"\b[wp]_?[0-9a-f]{6,}\b"), "<pane>"),
]
DROP = re.compile(r"^(exit=\d+$|.*lock.*(stale|out of date|mismatch).*|.*CACHE_WRITE_FAILED.*)", re.I)


def norm(path):
    out = []
    for line in path.read_text(errors="replace").splitlines():
        line = ANSI.sub("", line).rstrip()
        if DROP.match(line):
            continue
        for rx, rep in SUBS:
            line = rx.sub(rep, line)
        out.append(line)
    return out


def exit_of(path):
    m = re.findall(r"^exit=(\d+)$", path.read_text(errors="replace"), re.M)
    return m[-1] if m else "?"


def main():
    a, b = Path(sys.argv[1]), Path(sys.argv[2])
    gates = sys.argv[3:] or sorted(p.stem for p in b.glob("*.log"))
    for g in gates:
        pa, pb = a / f"{g}.log", b / f"{g}.log"
        if not pa.exists():
            print(f"== {g}: no log on the first side; second exit={exit_of(pb)}")
            continue
        if not pb.exists():
            print(f"== {g}: no log on the second side; first exit={exit_of(pa)}")
            continue
        la, lb = norm(pa), norm(pb)
        diff = list(difflib.unified_diff(la, lb, str(pa), str(pb), n=0, lineterm=""))
        head = f"== {g}: exit {exit_of(pa)} -> {exit_of(pb)}"
        if not diff:
            print(head + "  identical")
            continue
        changed = sum(1 for d in diff if d[:1] in "+-" and d[:3] not in ("+++", "---"))
        print(head + f"  {changed} line(s) differ")
        for d in diff[2:]:
            print("   " + d[:400])


if __name__ == "__main__":
    main()
