#!/usr/bin/env python3
"""SPIKE ONLY — part 2 scorer. Never merges.

Reads tmp/spike/out2/<id>/probe.out and compares each mutant's findings with the unmutated
baseline's, per setting (A, B). A row is RED when it carries a (member, family:rule) pair the
baseline does not. A run that did not finish, lost a member row, or exited non-zero is
INCOMPLETE, never clean.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out2")
ROW = re.compile(r"^FAMROW (\S+) ended=(ok|err) n=(\d+) A=\[([^\]]*)\] B=\[([^\]]*)\]\s*$")
EXPECTED_ROWS = 16


def parse(d):
    """-> (ok, why, {member: (ended, n, setA, setB)})"""
    p = os.path.join(d, "probe.out")
    rcp = os.path.join(d, "rc")
    if not os.path.exists(p) or not os.path.exists(rcp):
        return False, "no output", {}
    m = re.match(r"rc=(-?\d+) ", open(rcp).read())
    if not m or int(m.group(1)) != 0:
        return False, "probe exited " + (m.group(1) if m else "?"), {}
    text = open(p, encoding="utf-8", errors="replace").read()
    if "FAMPROBE end" not in text:
        return False, "probe did not reach its end line", {}
    rows = {}
    for line in text.splitlines():
        if line.startswith("FAMROW "):
            r = ROW.match(line)
            if not r:
                return False, "unparseable FAMROW: " + line[:80], {}
            name, ended, n, a, b = r.groups()
            if name in rows:
                return False, "duplicate member " + name, {}
            rows[name] = (ended, int(n),
                          frozenset(x for x in a.split(",") if x),
                          frozenset(x for x in b.split(",") if x))
    if len(rows) != EXPECTED_ROWS:
        return False, f"{len(rows)} member rows, expected {EXPECTED_ROWS}", {}
    return True, "", rows


def new_findings(base, rows, idx):
    """(member, rule) pairs present under the mutant and absent at baseline, for setting idx."""
    out = []
    for name, r in rows.items():
        b = base[name][idx] if name in base else frozenset()
        for rule in sorted(r[idx] - b):
            out.append((name, rule))
    return out


def score(mid, base):
    ok, why, rows = parse(os.path.join(OUT, mid))
    if not ok:
        return dict(id=mid, verdict_a="INCOMPLETE", verdict_b="INCOMPLETE", why=why, a=[], b=[], changed=0)
    if set(rows) != set(base):
        return dict(id=mid, verdict_a="INCOMPLETE", verdict_b="INCOMPLETE", why="member set differs from baseline",
                    a=[], b=[], changed=0)
    a = new_findings(base, rows, 2)
    b = new_findings(base, rows, 3)
    changed = sum(1 for k in rows if rows[k][:2] != base[k][:2])
    return dict(id=mid, verdict_a="RED" if a else "clean", verdict_b="RED" if b else "clean",
                why="", a=a, b=b, changed=changed)


def load_predictions():
    preds = {}
    p = os.path.join(HERE, "predictions2.tsv")
    for line in open(p, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        f = line.rstrip("\n").split("\t")
        preds[f[0]] = dict(a="RED" if f[1] == "RED" else "clean", b="RED" if f[2] == "RED" else "clean",
                           rule=f[3], conf=f[4])
    return preds


def main():
    ok, why, base = parse(os.path.join(OUT, "baseline"))
    if not ok:
        sys.exit("baseline unusable: " + why)
    preds = load_predictions()
    ids = [d for d in ["K0", "K1", "K2", "M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M12"]
           if os.path.isdir(os.path.join(OUT, d))]
    print("id\tA\tB\tmembers_changed\tpredicted_A\tpredicted_B\tA_match\tB_match\tnew findings (A)")
    right_a = right_b = 0
    for mid in ids:
        r = score(mid, base)
        p = preds.get(mid, dict(a="?", b="?", rule="", conf=""))
        ma = "yes" if r["verdict_a"] == p["a"] else "NO"
        mb = "yes" if r["verdict_b"] == p["b"] else "NO"
        right_a += ma == "yes"
        right_b += mb == "yes"
        rules = sorted({rule for _, rule in r["a"]})
        members = sorted({m for m, _ in r["a"]})
        detail = (", ".join(rules) + " on " + ", ".join(members)) if rules else r["why"]
        print("\t".join([mid, r["verdict_a"], r["verdict_b"], str(r["changed"]), p["a"], p["b"], ma, mb, detail]))
    print()
    for mid in ids:
        r = score(mid, base)
        only_b = sorted({rule for _, rule in r["b"]} - {rule for _, rule in r["a"]})
        if only_b:
            mem = sorted({m for m, rule in r["b"] if rule in only_b})
            print(f"{mid}\tB only\t{', '.join(only_b)} on {', '.join(mem)}")
    print(f"\nrows={len(ids)} predictions right: A {right_a}/{len(ids)}, B {right_b}/{len(ids)}")
    print("baseline: A findings on %d member(s); B findings on %d member(s)" % (
        sum(1 for v in base.values() if v[2]), sum(1 for v in base.values() if v[3])))


if __name__ == "__main__":
    main()
