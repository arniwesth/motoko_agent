#!/usr/bin/env python3
"""SPIKE ONLY, part 6 — compare two `make eval_matrix` runs row by row. Never merges.

A run of the matrix is not green at HEAD in this worktree, so the question is the one part 1
asked of `make dst`: does the second run ADD anything to the first? Compared: each suite's exit
code, each case's observed verdict / first finding / position, and each case's join status.
A missing file or a row present on one side only is reported, never counted as equal.
"""
import csv, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
def load(run):
    d = os.path.join(HERE, "out6", run)
    need = ["rc", "MATRIX.tsv", "logs/suites.json", "logs/join.tsv"]
    miss = [n for n in need if not os.path.exists(os.path.join(d, n))]
    if miss:
        sys.exit(f"{run}: INCOMPLETE, missing {', '.join(miss)}")
    rows = {r["case_id"]: r for r in csv.DictReader(open(os.path.join(d, "MATRIX.tsv"), encoding="utf-8"), delimiter="\t")}
    join = {r["case_id"]: r["status"] for r in csv.DictReader(open(os.path.join(d, "logs/join.tsv"), encoding="utf-8"), delimiter="\t")}
    suites = {s["suite"]: s["exit"] for s in json.load(open(os.path.join(d, "logs/suites.json")))}
    return dict(rc=open(os.path.join(d, "rc")).read().strip(), rows=rows, join=join, suites=suites)
def main():
    a, b = load("baseline"), load("proto")
    print(f"exit: baseline {a['rc']}, prototype {b['rc']}")
    print(f"suites: {len(a['suites'])} and {len(b['suites'])}; rows: {len(a['rows'])} and {len(b['rows'])}")
    only = sorted(set(a["suites"]) ^ set(b["suites"])) + sorted(set(a["rows"]) ^ set(b["rows"]))
    sd = [(s, a["suites"][s], b["suites"][s]) for s in sorted(set(a["suites"]) & set(b["suites"])) if a["suites"][s] != b["suites"][s]]
    F = ("observed_verdict", "observed_first_finding", "observed_position", "observed_by")
    rd = [(c, [f"{f}: {a['rows'][c][f]} -> {b['rows'][c][f]}" for f in F if a["rows"][c][f] != b["rows"][c][f]])
          for c in sorted(set(a["rows"]) & set(b["rows"]))]
    rd = [(c, d) for c, d in rd if d]
    jd = [(c, a["join"][c], b["join"][c]) for c in sorted(set(a["join"]) & set(b["join"])) if a["join"][c] != b["join"][c]]
    print(f"present on one side only: {len(only)}"); [print("  ", x) for x in only[:20]]
    print(f"suites whose exit code differs: {len(sd)}"); [print("  ", *x) for x in sd]
    print(f"rows whose observation differs: {len(rd)}"); [print("  ", c, "; ".join(d)[:200]) for c, d in rd[:40]]
    print(f"rows whose join status differs: {len(jd)}"); [print("  ", *x) for x in jd[:40]]
    print("VERDICT:", "IDENTICAL — the prototype adds nothing to the baseline" if not (only or sd or rd or jd) else "DIFFERS")
if __name__ == "__main__":
    main()
