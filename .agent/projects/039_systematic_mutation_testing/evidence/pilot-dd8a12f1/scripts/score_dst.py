#!/usr/bin/env python3
"""039 random-mutant pilot: the tier-4 scorer, for a full `make dst` sweep.

    score_dst.py <id>...      compare each id's failed targets with C-base's
    score_dst.py selftest

A sweep's verdict is its own summary block (`scripts/dst/sweep_summary.sh`): `FAILED (n):` and
one line per failed target. A tier-4 KILL is a target that failed under the mutant and PASSED in
the unmutated sweep (`runs/dst/C-base`); a target red in both can kill nothing. A sweep with no
summary block (a timeout, a crash of make itself) is INCOMPLETE and never green.
"""
import os
import re
import sys

E = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET_LINE = re.compile(r"^\s{4}(\S+)\s+(NEW|known-red)\b")


def parse(text):
    if "─── make dst ─" not in text:
        return None
    tail = text.split("─── make dst ─", 1)[1]
    if "all targets passed" in tail:
        return set()
    return {m.group(1) for l in tail.splitlines() for m in [TARGET_LINE.match(l)] if m}


def score(text, rc, base_failed):
    if rc == 124:
        return "TIMEOUT", []
    failed = parse(text)
    if failed is None:
        return "INCOMPLETE", []
    new = sorted(failed - base_failed)
    if new:
        return "KILL", new
    return ("GREEN" if not failed else "RED-AS-BASE"), sorted(failed)


def read(i):
    d = os.path.join(E, "runs", "dst", i)
    text = open(os.path.join(d, "out.txt"), encoding="utf-8").read()
    rcl = open(os.path.join(d, "rc"), encoding="utf-8").read()
    return text, int(re.search(r"rc=(\d+)", rcl).group(1)), re.search(r"wall_secs=(\d+)", rcl).group(1)


def selftest():
    green = "x\n─── make dst ───\n  1800s wall, -j8, load 1\n  all targets passed\n"
    red = "x\n─── make dst ───\n  FAILED (2):\n    discovery                    NEW — this one is yours\n    declared_vs_performed        known-red — listed\n"
    base = {"declared_vs_performed"}
    cases = [(green, 0, set(), "GREEN"), (red, 2, base, "KILL"),
             (red.replace("    discovery                    NEW — this one is yours\n", ""), 2, base, "RED-AS-BASE"),
             ("make: partial output", 124, base, "TIMEOUT"), ("make: partial output", 2, base, "INCOMPLETE")]
    ok = True
    for text, rc, b, want in cases:
        got, ts = score(text, rc, b)
        ok &= got == want
        print(f"{'ok  ' if got == want else 'FAIL'} {want}: {got} {ts}")
    print("score_dst selftest:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["selftest"]:
        sys.exit(selftest())
    btext, brc, _ = read("C-base")
    base = parse(btext)
    if base is None:
        sys.exit("C-base has no summary block; nothing can be scored against it")
    print(f"C-base failed: {sorted(base) or 'none'}")
    for i in a:
        text, rc, wall = read(i)
        st, ts = score(text, rc, base)
        print(f"{i}\t{st}\t{' '.join(ts) or '-'}\trc={rc}\twall_secs={wall}")
