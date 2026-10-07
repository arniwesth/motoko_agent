#!/usr/bin/env python3
"""Self-test of score.py on constructed gate outputs. No gate is run.

Each case is a way a mutant row could be read as a kill when it is not, or the reverse:
a timeout, a compile error, another rule red alone, the named rule red in the other direction,
a kill on a different member set, a run that stopped before its closing verdict.
"""
import importlib.util, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("score", os.path.join(HERE, "score.py"))
sc = importlib.util.module_from_spec(spec); spec.loader.exec_module(sc)

RULES = ["steps-not-contiguous", "provider-calls-exceed-budget", "retry-at-budget-edge",
         "provider-calls-unbalanced", "tool-dispatches-unbalanced", "request-ordinals-not-contiguous"]


def gate(red=None, family=None, upto=16, closing=True, guard=None):
    """A gate output. red: {(member, rule): detail}; family: {(member, rule): 'family: msg'}."""
    red, family = red or {}, family or {}
    out = ["→ Type checking...", "011 ADR-003 D1 — … (invariant-set/2)"]
    for m in sc.ALL16[:upto]:
        fam = {r: d for (mm, r), d in family.items() if mm == m}
        out.append(f"JUDGEROW {m} n=1 ended=Ok finish=stop set=[] checks=[] not_evaluated=[]")
        out.append(f"JUDGE {m} invariant-set " + (f"RED {len(fam)} finding(s); unevaluated=replay-consistency" if fam else "clean no finding; unevaluated=replay-consistency"))
        for r, d in fam.items():
            out.append(f"JUDGE {m} {r} RED {d}")
        for r in RULES:
            out.append(f"JUDGE {m} {r} " + (f"RED {red[(m, r)]}" if (m, r) in red else "clean facts"))
    out.append("CONTROL retry-with-two-steps-left steps-not-contiguous RED a control row never counts")
    if guard:
        out.append(f"  ✗ {guard}\n      detail")
    if closing:
        out.append("✗ corpus_judge FAILED" if (red or family or guard) else "✓ corpus_judge: 16 members, …")
    return "\n".join(out) + "\n"


def pred(expect, direction="-", members="seed-244", pid="x"):
    return {"id": pid, "expect_red": expect, "direction": direction, "members": members}


fails = 0
def check(name, got, want):
    global fails
    ok = want in got
    fails += not ok
    print(("  ✓ " if ok else "  ✗ ") + name + ("" if ok else f"\n      got {got!r}, wanted it to contain {want!r}"))


T = "tool-dispatches-unbalanced"
# 1. the plain kill, on the predicted member
r = sc.score(pred("provider-calls-exceed-budget"), gate(red={("seed-244", "provider-calls-exceed-budget"): "13 on 12"}), 2)
check("named rule red on the predicted member is a KILL", r["verdict"], "KILL"); check("… and as predicted", r["prediction"], "as predicted")
# 2. a timeout that printed nothing is not a kill, and not clean
r = sc.score(pred("provider-calls-exceed-budget"), "", 124)
check("a timeout is NOT A KILL: timeout", r["verdict"], "NOT A KILL: timeout")
# 3. a timeout AFTER printing clean rows for every member is still not 'survived'
r = sc.score(pred("provider-calls-exceed-budget"), gate(closing=False), 124)
check("a timeout after sixteen clean members is a timeout, not a survivor", r["verdict"], "NOT A KILL: timeout")
# 4. a compile error: non-zero exit, no member row
r = sc.score(pred("provider-calls-exceed-budget"), "→ Type checking...\nError: type mismatch at src/core/session.ail:3920\nmake: *** [Makefile:2017: corpus_judge] Error 1\n", 2)
check("a compile error is NOT A KILL: no member row", r["verdict"], "no member row")
# 5. another rule red alone
r = sc.score(pred("provider-calls-exceed-budget"), gate(red={("seed-244", "steps-not-contiguous"): "gap"}), 2)
check("another rule red alone is NOT A KILL", r["verdict"], "other rule(s) red alone"); check("… and it is named", r["others"], "steps-not-contiguous on seed-244")
# 6. the named rule in the other direction only
r = sc.score(pred(T, "log above trace", "DISPATCH10"), gate(red={(m, T): "log below trace: the trace holds 5" for m in sc.GROUPS["DISPATCH10"]}), 2)
check("the named rule red in the OTHER direction is not a kill of the case named", r["verdict"], "NOT A KILL")
# 7. the right direction, on a different member set: a kill and a prediction miss
r = sc.score(pred(T, "log above trace", "DISPATCH10"), gate(red={("seed-1", T): "log above trace: the trace holds 0"}), 2)
check("the right direction on other members is a KILL", r["verdict"], "KILL"); check("… and a prediction MISS", r["prediction"], "MISS")
# 8. a family finding is read from its own row, not from the invariant-set summary row
r = sc.score(pred("outcome-finish-disagrees", "-", "seed-244"), gate(family={("seed-244", "outcome-finish-disagrees"): "outcome-agreement: [outcome-finish-disagrees] …"}), 2)
check("a family finding's own row is a KILL", r["verdict"], "KILL"); check("… and invariant-set is not listed as another rule", r["others"], "none")
# 9. the summary row alone (a different family rule) is not a kill of the named one
r = sc.score(pred("outcome-finish-disagrees"), gate(family={("seed-244", "done-event-disagrees"): "outcome-agreement: [done-event-disagrees] …"}), 2)
check("a different family rule red is NOT A KILL", r["verdict"], "other rule(s) red alone")
# 10. a CONTROL row red never counts: gate() always holds one
r = sc.score(pred("steps-not-contiguous"), gate(), 0)
check("a CONTROL row with the named rule red does not count: SURVIVED", r["verdict"], "SURVIVED")
# 11. two rules named: one red is not the row's kill
r = sc.score(pred("provider-calls-unbalanced+request-ordinals-not-contiguous", "log below trace", "RETRY4", "r09"),
             gate(red={(m, "request-ordinals-not-contiguous"): "…" for m in sc.GROUPS["RETRY4"]}), 2)
check("one of two named rules red is NOT A KILL of the row", r["verdict"], "only request-ordinals-not-contiguous red")
# 12. r07's 'no other rule': a kill with company is a kill and a miss
r = sc.score(pred("provider-calls-exceed-budget", "-", "seed-244", "r07"),
             gate(red={("seed-244", "provider-calls-exceed-budget"): "13 on 12", ("seed-19", "retry-at-budget-edge"): "…"}), 2)
check("r07 with another rule red is a KILL", r["verdict"], "KILL"); check("… and a MISS on 'no other rule'", r["prediction"], "predicted no other rule red")
# 13. the named rule red, then the run stops: a kill, flagged incomplete
r = sc.score(pred("provider-calls-exceed-budget"), gate(red={("seed-1", "provider-calls-exceed-budget"): "…"}, upto=3, closing=False), 2)
check("named rule red in a run that stopped early is a KILL, flagged INCOMPLETE", r["verdict"], "KILL (run INCOMPLETE")
# 14. a guard crossed is reported
r = sc.score(pred("provider-calls-unbalanced", "log above trace", "ALL16", "P3"),
             gate(red={(m, "provider-calls-unbalanced"): "log above trace: the trace holds 0" for m in sc.ALL16},
                  guard="every member's trace holds a prepared call and a request ordinal"), 2)
check("P3: KILL", r["verdict"], "KILL"); check("… as predicted, with the guard red", r["prediction"], "as predicted")

print(f"\n{'✓ score_selftest: all cases pass' if not fails else f'✗ score_selftest: {fails} case(s) FAILED'}")
sys.exit(1 if fails else 0)
