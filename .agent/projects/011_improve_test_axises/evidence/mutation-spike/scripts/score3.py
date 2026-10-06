#!/usr/bin/env python3
"""SPIKE ONLY — part 3 scorer: tool-handoff mutants and their reach probes. Never merges.

For each handoff n: P<n> tells which gates REACH it (red, and the gate's log holds the poison's
`panic: division by zero`); T<n> tells which gates go red on the real mutant. A gate that did
not reach the handoff says nothing about the mutant. A mutant no gate reached is NOT REACHED,
never survived. A missing step is INCOMPLETE, never green.
"""
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out3")
GATES = ["corpus_pr", "strict_replay", "discovery", "stream_parity", "ledger_parity", "world_state"]
PANIC = "panic: division by zero"
ANSI = re.compile(r"\x1b\[[0-9;]*m")

spec = importlib.util.spec_from_file_location("score2", os.path.join(HERE, "score2.py"))
score2 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(score2)


def steps_of(d):
    p = os.path.join(d, "summary.tsv")
    if not os.path.exists(p):
        return None
    st = {}
    for line in open(p, encoding="utf-8", errors="replace"):
        f = line.rstrip("\n").split("\t")
        if f[0] == "step" and len(f) >= 3:
            m = re.fullmatch(r"rc=(-?\d+)", f[2])
            st[f[1]] = int(m.group(1)) if m else None
    return st


def text(d, name):
    p = os.path.join(d, name)
    return ANSI.sub("", open(p, encoding="utf-8", errors="replace").read()) if os.path.exists(p) else ""


def only_ceiling(t):
    fails = [l for l in t.splitlines() if re.search(r"(^|\s)(FAIL|✗)", l) and not l.lstrip().startswith("{")]
    return bool(fails) and all("against a declared ceiling" in l for l in fails)


def complete(st):
    if st is None or st.get("check") is None:
        return False, "no summary or no type-check rc"
    if st["check"] != 0:
        return False, "type check failed"
    missing = [g for g in GATES + ["bank_probe"] if st.get(g) is None]
    return (not missing), ("missing " + ",".join(missing) if missing else "")


def red_gates(d, st):
    out = []
    for g in GATES:
        if st[g] in (0, 124):
            continue
        if only_ceiling(text(d, g + ".log")):
            continue
        out.append(g)
    return out


def reach(n):
    """-> (ok, why, reached gates, red-without-panic gates, bank reached?)"""
    d = os.path.join(OUT, f"P{n}")
    st = steps_of(d)
    ok, why = complete(st)
    if not ok:
        return False, why, [], [], None
    reds = red_gates(d, st)
    # corpus_pr's recipe prints only the last 40 lines on failure; its full output is kept as .wire
    def shown(g):
        return text(d, g + ".log") + (text(d, "corpus_pr.wire") if g == "corpus_pr" else "")
    reached = [g for g in reds if PANIC in shown(g)]
    odd = [g for g in reds if g not in reached]
    bank = st["bank_probe"] != 0 and PANIC in text(d, "probe.out")
    return True, "", reached, odd, bank


def mutant(n, base_rows):
    d = os.path.join(OUT, f"T{n}")
    st = steps_of(d)
    ok, why = complete(st)
    if not ok:
        return dict(ok=False, why=why)
    reds = red_gates(d, st)
    pok, pwhy, rows = score2.parse(d)
    if not pok:
        fam = ("INCOMPLETE", pwhy, [])
    else:
        a = score2.new_findings(base_rows, rows, 2)
        fam = ("RED" if a else "clean", "", a)
    return dict(ok=True, reds=reds, fam=fam)


def verdict(n, base_rows):
    rok, rwhy, reached, odd, bank = reach(n)
    m = mutant(n, base_rows)
    if not rok or not m["ok"]:
        return dict(n=n, verdict="INCOMPLETE", why=(rwhy or m.get("why", "")), reached=reached, reds=[], odd=odd,
                    bank=bank, fam=("-", "", []), unreached_kill=[], reached_green=[])
    reds = m["reds"]
    unreached_kill = [g for g in reds if g not in reached]
    reached_green = [g for g in reached if g not in reds]
    if reds:
        v = "KILLED"
    elif reached or bank:
        v = "SURVIVED"
    else:
        v = "NOT REACHED"
    return dict(n=n, verdict=v, why="", reached=reached, reds=reds, odd=odd, bank=bank, fam=m["fam"],
                unreached_kill=unreached_kill, reached_green=reached_green)


def main():
    bok, bwhy, base_rows = score2.parse(os.path.join(OUT, "baseline-3"))
    if not bok:
        sys.exit("baseline-3 probe unusable: " + bwhy)
    bst = steps_of(os.path.join(OUT, "baseline-3"))
    ok, why = complete(bst)
    if not ok or red_gates(os.path.join(OUT, "baseline-3"), bst) or bst["bank_probe"] != 0:
        sys.exit("baseline-3 is not green: " + (why or str(bst)))
    print("handoff\tverdict\tgates that reach it\tgates red on the mutant\treached but green\tbank reached\tfamilies on bank (A)")
    for n in (1, 2, 3):
        r = verdict(n, base_rows)
        fam = r["fam"][0] + (": " + ", ".join(sorted({x for _, x in r["fam"][2]})) if r["fam"][2] else "")
        print("\t".join([f"T{n}", r["verdict"] + (f" ({r['why']})" if r["why"] else ""),
                         ",".join(r["reached"]) or "-", ",".join(r["reds"]) or "-",
                         ",".join(r["reached_green"]) or "-", str(r["bank"]), fam]))
        if r["odd"]:
            print(f"  note: P{n} red WITHOUT the poison's panic in: {','.join(r['odd'])} — not credited as reach")
        if r["unreached_kill"]:
            print(f"  note: T{n} red in a gate P{n} did not reach: {','.join(r['unreached_kill'])}")


if __name__ == "__main__":
    main()
