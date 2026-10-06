#!/usr/bin/env python3
"""SPIKE ONLY — the part-2 scorer on planted inputs. Every case must come back as named."""
import os, sys, tempfile, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("score2", os.path.join(HERE, "score2.py"))
s2 = importlib.util.module_from_spec(spec); spec.loader.exec_module(s2)
real = open(os.path.join(HERE, "out2", "baseline", "probe.out"), encoding="utf-8", errors="replace").read()
rows = [l for l in real.splitlines() if l.startswith("FAMROW ")]
assert len(rows) == 16, len(rows)

def mk(root, name, lines, rc=0, end=True):
    d = os.path.join(root, name); os.makedirs(d)
    open(os.path.join(d, "probe.out"), "w").write("FAMPROBE begin\n" + "\n".join(lines) + ("\nFAMPROBE end\n" if end else "\n"))
    open(os.path.join(d, "rc"), "w").write(f"rc={rc} secs=1 rows={len(lines)} end={1 if end else 0}\n")

def swap(lines, member, a=None, b=None, ended=None, n=None):
    out = []
    for l in lines:
        m = s2.ROW.match(l)
        if m.group(1) == member:
            name, e, nn, aa, bb = m.groups()
            l = f"FAMROW {name} ended={ended or e} n={n or nn} A=[{aa if a is None else a}] B=[{bb if b is None else b}]"
        out.append(l)
    return out

cases = [
  ("identical to baseline", rows, 0, True, "clean", "clean"),
  ("a new finding under A and B", swap(rows, "seed-9", a="bounded-progress:provider-step-repeated", b="bounded-progress:provider-step-repeated"), 0, True, "RED", "RED"),
  ("a new finding under B only", swap(rows, "seed-9", b="bounded-progress:retry-bound-exceeded"), 0, True, "clean", "RED"),
  # the baseline's own B finding on seed-1 must not count as new
  ("baseline's B finding repeated", swap(rows, "seed-1", b="bounded-progress:decision-budget-exceeded"), 0, True, "clean", "clean"),
  # behaviour changed (ended, n) with no finding: still clean, and counted as changed
  ("trajectory changed, no finding", swap(rows, "seed-9", ended="err", n="16"), 0, True, "clean", "clean"),
  ("a member row missing", rows[:-1], 0, True, "INCOMPLETE", "INCOMPLETE"),
  ("no end line", rows, 0, False, "INCOMPLETE", "INCOMPLETE"),
  ("probe exited non-zero", rows, 1, True, "INCOMPLETE", "INCOMPLETE"),
  ("a row that does not parse", rows[:-1] + ["FAMROW broken"], 0, True, "INCOMPLETE", "INCOMPLETE"),
]
bad = 0
for label, lines, rc, end, ea, eb in cases:
    with tempfile.TemporaryDirectory() as root:
        mk(root, "baseline", rows); mk(root, "X", lines, rc, end); s2.OUT = root
        ok, why, base = s2.parse(os.path.join(root, "baseline")); assert ok, why
        r = s2.score("X", base)
        good = (r["verdict_a"], r["verdict_b"]) == (ea, eb)
        if label.startswith("trajectory"): good = good and r["changed"] == 1
        print(("ok  " if good else "BAD ") + f"{label}: A={r['verdict_a']} B={r['verdict_b']} changed={r['changed']} {r['why']}")
        bad += 0 if good else 1
print(f"selftest: {len(cases) - bad}/{len(cases)}"); sys.exit(1 if bad else 0)
