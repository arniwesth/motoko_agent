#!/usr/bin/env python3
"""Compare two `make eval_matrix` runs row by row.

    compare_matrix.py BASELINE_DIR OTHER_DIR

Each directory holds a run's `MATRIX.tsv` and, from its `--logs` directory, `suites.json` and
`join.tsv`. Compared: every suite's exit code, every case's observed verdict, first finding,
position and observer, and every case's join status. The `commit` column is not compared.
A file missing on either side, or a suite or row present on one side only, is a difference.

Exit 0 when nothing differs, 1 when something does, 2 when a file is missing.
Adapted from `../mutation-spike/scripts/compare6.py`, which hardcodes its two directories.
"""
import csv, json, os, sys

FIELDS = ("observed_verdict", "observed_first_finding", "observed_position", "observed_by")


def load(d):
    need = ["MATRIX.tsv", "suites.json", "join.tsv"]
    miss = [n for n in need if not os.path.exists(os.path.join(d, n))]
    if miss:
        print(f"{d}: INCOMPLETE, missing {', '.join(miss)}")
        sys.exit(2)
    rows = {r["case_id"]: r for r in csv.DictReader(open(os.path.join(d, "MATRIX.tsv"), encoding="utf-8"), delimiter="\t")}
    join = {r["case_id"]: r["status"] for r in csv.DictReader(open(os.path.join(d, "join.tsv"), encoding="utf-8"), delimiter="\t")}
    suites = {s["suite"]: s["exit"] for s in json.load(open(os.path.join(d, "suites.json")))}
    return rows, join, suites


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    (ar, aj, asu), (br, bj, bsu) = load(sys.argv[1]), load(sys.argv[2])
    print(f"suites: {len(asu)} and {len(bsu)}; rows: {len(ar)} and {len(br)}")
    only = sorted(set(asu) ^ set(bsu)) + sorted(set(ar) ^ set(br)) + sorted(set(aj) ^ set(bj))
    sd = [(s, asu[s], bsu[s]) for s in sorted(set(asu) & set(bsu)) if asu[s] != bsu[s]]
    rd = [(c, [f"{f}: {ar[c][f]} -> {br[c][f]}" for f in FIELDS if ar[c][f] != br[c][f]]) for c in sorted(set(ar) & set(br))]
    rd = [(c, d) for c, d in rd if d]
    jd = [(c, aj[c], bj[c]) for c in sorted(set(aj) & set(bj)) if aj[c] != bj[c]]
    print(f"present on one side only: {len(only)}")
    for x in only[:40]:
        print("  ", x)
    print(f"suites whose exit code differs: {len(sd)}")
    for x in sd:
        print("  ", *x)
    print(f"rows whose observation differs: {len(rd)}")
    for c, d in rd[:60]:
        print("  ", c, "; ".join(d)[:240])
    print(f"rows whose join status differs: {len(jd)}")
    for x in jd[:60]:
        print("  ", *x)
    same = not (only or sd or rd or jd)
    print("VERDICT:", "IDENTICAL" if same else "DIFFERS")
    sys.exit(0 if same else 1)


if __name__ == "__main__":
    main()
