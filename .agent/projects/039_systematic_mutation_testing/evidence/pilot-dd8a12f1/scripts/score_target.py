#!/usr/bin/env python3
"""039 random-mutant pilot: the tier-3 and tier-4 scorer, for any make target but corpus_judge.

    score_target.py <target> <id>...     one line per id from runs/<target>/<id>/{out.txt,rc}
    score_target.py selftest             the planted cases

These targets print no JUDGE rows, so a kill here is a target that went RED on a content check,
named by the line that says so. Everything else is recorded as what it is:

  TIMEOUT        rc 124
  PANIC          a runtime failure (`panic:` or `Error: execution failed`)
  COMPILE        a type or parse error before the program ran
  CEILING-ONLY   corpus_pr red, and its one failure is its own wall-clock ceiling (the brief:
                 re-run once)
  RED            rc != 0 and a failure line naming a check; the lines are reported
  RED-UNNAMED    rc != 0 and no line this scorer recognises as naming a check
  GREEN          rc 0
"""
import os
import re
import sys

E = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAIL = re.compile(r"^\s*(✗|FAIL\b|FAIL:|.*\bFAIL(ED)?\b|.*: FAIL)")
CEILING = re.compile(r"FAIL: the PR corpus target took \d+ ms against a declared ceiling")


def score_text(target, text, rc):
    lines = text.splitlines()
    fails = [l.strip() for l in lines if FAIL.match(l) and "0 FAIL" not in l and "FAIL=0" not in l]
    panic = next((l.strip() for l in lines if "panic:" in l or "execution failed" in l), None)
    compile_err = next((l.strip() for l in lines if l.startswith("Error:") and ("type error" in l or "parse error" in l)), None)
    if rc == 124:
        return "TIMEOUT", fails
    if rc == 0:
        return "GREEN", []
    if panic:
        return "PANIC", [panic] + fails
    if compile_err:
        return "COMPILE", [compile_err]
    if target == "corpus_pr" and fails and all(CEILING.search(f) for f in fails):
        return "CEILING-ONLY", fails
    if fails:
        return "RED", fails
    return "RED-UNNAMED", [l.strip() for l in lines[-5:]]


def score_id(target, i):
    d = os.path.join(E, "runs", target, i)
    text = open(os.path.join(d, "out.txt"), encoding="utf-8").read()
    rcl = open(os.path.join(d, "rc"), encoding="utf-8").read()
    rc = int(re.search(r"rc=(\d+)", rcl).group(1))
    wall = re.search(r"wall_secs=(\d+)", rcl).group(1)
    state, lines = score_text(target, text, rc)
    return state, lines, rc, wall


CASES = [
    ("corpus_pr", "  ✓ a\n  ✓ measured CI cost, WHOLE TARGET: 90000 ms against a declared ceiling of 600000 ms\n", 0, "GREEN"),
    ("corpus_pr", "  ✓ a\nFAIL: the PR corpus target took 700000 ms against a declared ceiling of 600000 ms.\n      Re-measure\n", 2, "CEILING-ONLY"),
    ("corpus_pr", "FAIL: the fixed bank reached the fault class and the wire carries NO\n      record of the recovery branch 'session.c2_loop/stream_error_retry' executing.\n", 2, "RED"),
    ("ledger_parity", "  ✗ stream_error_retry: projected 3, appended 0\n", 1, "RED"),
    ("discovery", "partial output, then the timeout\n", 124, "TIMEOUT"),
    ("check_core", "Error: execution failed: RT001: integer division by zero at src/core/session.ail:1:1\n", 1, "PANIC"),
    ("strict_replay", "Error: type error in src/core/session (decl 118): undefined variable\n", 1, "COMPILE"),
    ("stream_parity", "make: *** [Makefile:325: stream_parity] Error 1\n", 2, "RED-UNNAMED"),
    ("dst", "  ✓ 52 targets\nPASS=52 FAIL=0\n", 0, "GREEN"),
]


def selftest():
    ok = True
    for target, text, rc, want in CASES:
        got, lines = score_text(target, text, rc)
        ok &= got == want
        print(f"{'ok  ' if got == want else 'FAIL'} {target} rc={rc}: {got} {lines[:1]}")
    # a ceiling line beside a content failure is a content failure, not CEILING-ONLY
    got, _ = score_text("corpus_pr", "  ✗ a content check\nFAIL: the PR corpus target took 700000 ms against a declared ceiling of 600000 ms.\n", 2)
    ok &= got == "RED"
    print(f"{'ok  ' if got == 'RED' else 'FAIL'} a content failure beside the ceiling: {got}")
    print("score_target selftest:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["selftest"]:
        sys.exit(selftest())
    elif len(a) >= 2:
        print("target\tid\tstate\tfirst failure lines\trc\twall_secs")
        for i in a[1:]:
            state, lines, rc, wall = score_id(a[0], i)
            print("\t".join([a[0], i, state, " | ".join(lines[:3])[:400] or "-", str(rc), wall]))
    else:
        sys.exit(__doc__)
