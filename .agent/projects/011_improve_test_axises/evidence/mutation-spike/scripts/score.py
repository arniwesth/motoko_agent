#!/usr/bin/env python3
"""SPIKE ONLY — reads tmp/spike/out/<id>/ and prints one row per mutant. Never merges.

A kill is read from a gate's exit status only. The signature is searched in the predicted
gate's own log only. A missing step or a non-integer rc is INCOMPLETE, never a pass.
"""
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("mutants", os.path.join(HERE, "mutants.py"))
mutants = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mutants)

GATES = ["corpus_pr", "strict_replay", "discovery", "stream_parity", "ledger_parity"]
OUT = os.path.join(HERE, "out")
ANSI = re.compile(r"\x1b\[[0-9;]*m")


def read_summary(d):
    steps, meta = {}, {}
    p = os.path.join(d, "summary.tsv")
    if not os.path.exists(p):
        return None, None
    for line in open(p, encoding="utf-8", errors="replace"):
        f = line.rstrip("\n").split("\t")
        if f[0] == "step" and len(f) >= 4:
            m = re.fullmatch(r"rc=(-?\d+)", f[2])
            s = re.fullmatch(r"secs=(\d+)", f[3])
            steps[f[1]] = (int(m.group(1)) if m else None, int(s.group(1)) if s else None)
        elif len(f) >= 2:
            meta[f[0]] = f[1]
    return steps, meta


def log_text(d, gate):
    p = os.path.join(d, gate + ".log")
    if not os.path.exists(p):
        return ""
    return ANSI.sub("", open(p, encoding="utf-8", errors="replace").read())


def first_failures(text, n=2):
    """The first lines a gate itself marks as failing. Evidence, not a verdict."""
    hits = [l.strip() for l in text.splitlines()
            if re.search(r"(^|\s)(FAIL|✗)", l) and not l.lstrip().startswith("{")]
    return [h[:230] for h in hits[:n]]


def only_timing(text):
    fails = [l for l in text.splitlines() if re.search(r"(^|\s)(FAIL|✗)", l) and not l.lstrip().startswith("{")]
    return bool(fails) and all("against a declared ceiling" in l for l in fails)


def verdict(m, steps, d):
    if steps is None:
        return "INCOMPLETE", "no summary"
    if "check" not in steps or steps["check"][0] is None:
        return "INCOMPLETE", "no type-check rc"
    if steps["check"][0] != 0:
        return "COMPILE_FAIL", ""
    missing = [g for g in GATES if g not in steps or steps[g][0] is None]
    if missing:
        return "INCOMPLETE", "missing " + ",".join(missing)
    timed_out = [g for g in GATES if steps[g][0] == 124]
    red = [g for g in GATES if steps[g][0] not in (0, 124)]
    # A gate that is red ONLY on its own wall-clock ceiling measured the machine, not the mutant.
    timing = [g for g in red if only_timing(log_text(d, g))]
    red = [g for g in red if g not in timing]
    if not red and (timed_out or timing):
        return "TIMEOUT", ",".join(timed_out + [g + "(ceiling)" for g in timing])
    if not red:
        return "SURVIVED_T", ""
    return "KILLED", ",".join(red)


def row(m):
    d = os.path.join(OUT, m["id"])
    steps, meta = read_summary(d)
    v, detail = verdict(m, steps, d)
    red = detail.split(",") if v == "KILLED" else []
    sig = ""
    if v == "KILLED":
        if m["predict"] != "KILL":
            match = "killed, predicted to survive"
        elif m["gate"] not in red:
            match = f"killed by another gate (predicted {m['gate']})"
        elif m["signature"]:
            found = re.search(m["signature"], log_text(d, m["gate"])) is not None
            sig = "yes" if found else "no"
            match = "as predicted" if found else "predicted gate, different check"
        else:
            match = "predicted gate (no signature named)"
    elif v == "SURVIVED_T":
        match = "as predicted" if m["predict"] == "SURVIVE" else "survived, predicted to be killed"
    else:
        match = "-"
    return dict(id=m["id"], verdict=v, detail=detail, predict=m["predict"], pgate=m["gate"],
                match=match, sig=sig, steps=steps or {}, meta=meta or {}, dir=d, red=red)


def main():
    rows = [row(m) for m in mutants.MUTANTS if os.path.isdir(os.path.join(OUT, m["id"]))]
    if not rows:
        sys.exit("no mutant output directories found")
    hdr = ["id", "check", "contract"] + GATES + ["secs", "verdict", "predicted", "match"]
    print("\t".join(hdr))
    for r in rows:
        st = r["steps"]
        def rc(k):
            return "-" if k not in st or st[k][0] is None else ("ok" if st[k][0] == 0 else f"RED({st[k][0]})")
        secs = sum(v[1] or 0 for k, v in st.items() if k in ("check", "contract")) + max(
            [st[g][1] or 0 for g in GATES if g in st] or [0])
        print("\t".join([r["id"], rc("check"), rc("contract")] + [rc(g) for g in GATES]
                        + [str(secs), r["verdict"], r["predict"], r["match"]]))
    print()
    for r in rows:
        for g in r["red"]:
            for l in first_failures(log_text(r["dir"], g)):
                print(f"{r['id']}\t{g}\t{l}")
        ww = [l.strip() for l in log_text(r["dir"], "corpus_pr").splitlines() if "wire witness, branch-reached" in l]
        if ww:
            print(f"{r['id']}\tcorpus_pr witness\t{ww[0][:260]}")
    k = [r for r in rows if r["verdict"] == "KILLED"]
    s = [r for r in rows if r["verdict"] == "SURVIVED_T"]
    right = [r for r in rows if r["match"].startswith("as predicted") or r["match"].startswith("predicted gate (no")]
    print(f"\nrows={len(rows)} killed={len(k)} survived_T={len(s)} "
          f"other={len(rows) - len(k) - len(s)} predictions_right_at_gate_level={len(right)}")


if __name__ == "__main__":
    main()
