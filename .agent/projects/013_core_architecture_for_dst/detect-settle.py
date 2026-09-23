#!/usr/bin/env python3
"""detect-settle — refuse a `done` that its own attempt record contradicts.

WHY. Five times in this run a task projected `done` while its own row table had open
items, and each time a human read the receipt by hand and sent a correction:

    P2.3  06:39Z  (a14)   P2.3  09:22Z  (a18)   P2.3  11:37Z  (a20)
    P2.2  19:30Z  (a14, a receipt titled "STOP REPORT")
    P2.3  2026-09-20     (a37, progress 9/18)   <- live when this was written

Per `.agent/meta-decisions/measure-review-loop-convergence-and-build-detectors-instead-of-
specifying-them.md` rule 2, the third occurrence should already have been a script. This is it.

THE ONE-SIDED TRAP. Three of the four historical cases carry `progress: null`, so a detector
that only compares done<total is SILENT on exactly the cases it exists for — blind in the
direction that matters (rule 3). Absent progress is therefore reported, not passed over: as a
WARN when the attempt has a receipt (a real delegation that should carry progress, ADR-001 D2),
and skipped only for declared summaries, which have no row table to count. Run --strict to fail
on warnings too.

Read-only. Writes nothing, edits nothing. Exit 0 clean, 1 refusal (or any finding under
--strict), 2 usage.

    python3 detect-settle.py <run.json> [--json] [--strict]
"""
import json
import sys

# states that assert the work finished; a task in one of these is making a claim
CLAIMS_COMPLETE = {"done"}
# terminal states that assert the opposite, or assert nothing about completeness
NO_CLAIM = {"queued", "working", "blocked", "failed", "rejected", "canceled",
            "settled_unverified", "review"}


def findings(doc):
    """(severity, task, code, detail). REFUSE fails; WARN needs --strict.

    A summary attempt — one the producer declared from the operator's plan rather than
    observing — has no receipt and no row table, so there is nothing to count and it is
    skipped. Measured: 33 of 42 tasks in this run are such summaries, and treating them
    as findings buried the one real hit. The receipt is the discriminator: if a delegate
    answered, there is a row table; if not, there is not.
    """
    out = []
    for t in doc.get("tasks", []):
        state = t.get("state")
        if state not in CLAIMS_COMPLETE:
            if state not in NO_CLAIM:
                out.append(("WARN", t["id"], "UNKNOWN_STATE", f"state {state!r} unknown"))
            continue
        atts = t.get("attempts") or []
        if not atts:
            out.append(("REFUSE", t["id"], "DONE_NO_ATTEMPT", "done with no attempt"))
            continue
        a = atts[-1]
        receipt = (a.get("outcome") or {}).get("receipt")
        if not receipt:
            continue                                   # declared summary, nothing to count
        p = a.get("progress")
        if p is None:
            out.append(("WARN", t["id"], "DONE_PROGRESS_ABSENT",
                        f"{a['id']} has a receipt but no progress; completeness unverifiable "
                        "(ADR-001 D2)"))
            continue
        done, total = p.get("done"), p.get("total")
        if not isinstance(done, int) or not isinstance(total, int) or total <= 0:
            out.append(("REFUSE", t["id"], "DONE_PROGRESS_MALFORMED", f"{a['id']} progress={p!r}"))
        elif done < total:
            out.append(("REFUSE", t["id"], "DONE_INCOMPLETE",
                        f"{a['id']} claims done at {done}/{total} — {total - done} row(s) open"))
    return out


def main(argv):
    if not 2 <= len(argv) <= 4:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    try:
        doc = json.load(open(argv[1]))
    except Exception as e:                                    # noqa: BLE001 - report, don't raise
        print(f"detect-settle: cannot read {argv[1]}: {e}", file=sys.stderr)
        return 2
    f = findings(doc)
    strict = "--strict" in argv
    if "--json" in argv:
        print(json.dumps([{"severity": s, "task": t, "code": c, "detail": d}
                          for s, t, c, d in f], indent=1))
    else:
        for s, t, c, d in f:
            print(f"{s:<6} {t:<8} {c:<24} {d}")
        n_ref = sum(1 for s, *_ in f if s == "REFUSE")
        print(f"--- {n_ref} refusal(s), {len(f) - n_ref} warning(s) over "
              f"{len(doc.get('tasks', []))} tasks")
    return 1 if any(s == "REFUSE" for s, *_ in f) or (strict and f) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
