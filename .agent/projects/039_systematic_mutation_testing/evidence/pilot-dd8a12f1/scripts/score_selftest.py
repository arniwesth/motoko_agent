#!/usr/bin/env python3
"""The scorer's planted cases, run before it reads any real result.

The spike's scorer once read a timed-out gate as green. Each case below is an output a careless
scorer could misread; each must get exactly the state written beside it.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from score import score_text  # noqa: E402

MEMBERS = [f"seed-{n}" for n in (1, 3, 4, 6, 8, 11, 14, 18, 29, 31, 60, 61, 71, 102, 109, 165, 215)] + ["constructed-empty-terminal"]
HEAD = "011 ADR-003 D1 — the invariant set and six two-channel checks (invariant-set/2)\n"


def member(m, red=None, not_eval=None):
    out = [f"JUDGEROW {m} n=10 ended=Ok finish=stop set=[] checks=[] not_evaluated=[]"]
    if red == "set":
        out += [f"JUDGE {m} invariant-set RED 1 finding(s); unevaluated=replay-consistency",
                f"JUDGE {m} outcome-finish-disagrees RED outcome-agreement: ..."]
    else:
        out += [f"JUDGE {m} invariant-set clean no finding; unevaluated=replay-consistency"]
    for r in ("steps-not-contiguous", "provider-calls-exceed-budget", "retry-at-budget-edge",
              "provider-calls-unbalanced", "tool-dispatches-unbalanced", "request-ordinals-not-contiguous"):
        if red == r:
            out.append(f"JUDGE {m} {r} RED trace=3 log=2")
        elif not_eval == r:
            out.append(f"JUDGE {m} {r} not-evaluated the step budget is undeclared")
        else:
            out.append(f"JUDGE {m} {r} clean trace=3 log=3")
    return "\n".join(out)


def bank(red_member=None, red=None, upto=18, not_eval=None):
    return "\n".join(member(m, red if m == red_member else None, not_eval if m == red_member else None)
                     for m in MEMBERS[:upto])


GREEN_TAIL = "\n  ✓ every member's trace holds a prepared call\n\n✓ corpus_judge: 18 members, the invariant set and six checks\n"
RED_TAIL = "\n\n✗ corpus_judge FAILED\n"
CONTROL_RED = "CONTROL tool-run-without-approval tool-dispatches-unbalanced RED trace=2 log=0\n"

CASES = [
    ("a clean complete run", HEAD + bank() + GREEN_TAIL, 0, "GREEN"),
    ("a family rule red on one member", HEAD + bank("seed-4", "set") + RED_TAIL, 2, "KILL"),
    ("a gate check red on one member", HEAD + bank("seed-215", "provider-calls-exceed-budget") + RED_TAIL, 2, "KILL"),
    ("a timeout after eight clean members and no verdict", HEAD + bank(upto=8), 124, "TIMEOUT"),
    ("a timeout after a red row", HEAD + bank("seed-1", "steps-not-contiguous", upto=3), 124, "TIMEOUT"),
    ("a panic before any member row", HEAD + "panic: division by zero\n", 2, "PANIC"),
    ("a panic after the bank (a control reached it)", HEAD + bank() + "\npanic: division by zero\n", 2, "PANIC"),
    ("a v0.60.4 runtime error after five members", HEAD + bank(upto=5) + "\nError: execution failed: RT001: integer division by zero at src/core/session.ail:3523:13\n", 1, "PANIC"),
    ("a compile error", "→ Type checking...\nError: type error in src/core/session (decl 118): ...\n", 1, "COMPILE"),
    ("a run that stopped at member 12 with exit 0", HEAD + bank(upto=12), 0, "INCOMPLETE"),
    ("only a CONTROL row red", HEAD + bank() + "\n" + CONTROL_RED + RED_TAIL, 2, "RED-NO-KILL"),
    ("only a guard red", HEAD + bank() + "\n  ✗ a member dispatched a tool (0 of 16)" + RED_TAIL, 2, "RED-NO-KILL"),
    ("only a not-evaluated rule", HEAD + bank("seed-1", None, not_eval="retry-at-budget-edge") + RED_TAIL, 2, "RED-NO-KILL"),
    ("green rows but exit 2 and a red verdict", HEAD + bank() + RED_TAIL, 2, "RED-NO-KILL"),
]


def main():
    ok = True
    for name, text, rc, want in CASES:
        got = score_text(text, rc)
        state = got["state"].split(" ")[0]
        mark = "ok  " if state == want else "FAIL"
        ok &= state == want
        print(f"{mark} {name}: {got['state']} | kills={got['kills']} | also={got['also'][:90]}")
    # a kill must name the rule and the member, and a CONTROL red is never a kill
    k = score_text(HEAD + bank("seed-4", "set") + "\n" + CONTROL_RED + RED_TAIL, 2)
    if not (k["state"] == "KILL" and "outcome-finish-disagrees on seed-4" in k["kills"]
            and "invariant-set" not in k["kills"] and "CONTROL tool-dispatches-unbalanced RED on tool-run-without-approval" in k["also"]):
        print(f"FAIL kill naming: {k}")
        ok = False
    else:
        print("ok   a kill names its rule and member; the aggregate row and a CONTROL row are not kills")
    # two findings of one rule on one member count that member once
    two = (HEAD + bank("seed-4", "set") + RED_TAIL).replace(
        "JUDGE seed-4 outcome-finish-disagrees RED outcome-agreement: ...",
        "JUDGE seed-4 outcome-finish-disagrees RED outcome-agreement: a\nJUDGE seed-4 outcome-finish-disagrees RED outcome-agreement: b")
    d = score_text(two, 2)
    if d["kills"] != "outcome-finish-disagrees on seed-4 (1)":
        print(f"FAIL member count: {d['kills']}")
        ok = False
    else:
        print("ok   two findings of one rule on one member count the member once")
    print("score_selftest:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
