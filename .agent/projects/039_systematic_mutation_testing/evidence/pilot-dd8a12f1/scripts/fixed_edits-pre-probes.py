#!/usr/bin/env python3
"""039 random-mutant pilot: the edits that are NOT drawn. Controls and reach probes.

    fixed_edits.py list
    fixed_edits.py check <root>        every edit's old text matches exactly once; writes nothing
    fixed_edits.py apply <id> <root>   make that one replacement under <root>

The known-bad rows are acceptance-ce9cb247's (011 evidence, `scripts/apply_mutant.py`), re-anchored
by their TEXT at dd8a12f1, not by line. Each must go red on the rule it names there. The reach
probes are added after tier 1, one per tier-1 survivor (sequence.log says when); each makes one
expression panic with an integer division by zero if it is ever evaluated, and changes nothing else.
"""
import sys

S = "src/core/session.ail"
SM = "src/core/step_machine.ail"
R = "src/core/recovery.ail"
T = "src/core/tool_phase.ail"

# id, file, anchor (or None), old, new, what it is
EDITS = [
    ("K0", S, None,
     "let retry_event = StreamErrorRetry({ step: step_idx, error: e.message });",
     "let retry_event = StreamErrorRetry({ step: step_idx, error: e.message }); -- 039 pilot comment-only control",
     "comment-only edit in the retry branch (acceptance's K0)"),
    ("KB-r01", S, None,
     "step_idx, TermProviderFailure, e.message, started_at_ms, capt.trace",
     "step_idx, TermSuccess, e.message, started_at_ms, capt.trace",
     "acceptance r01: the failure finalize reports TermSuccess; must be red on outcome-finish-disagrees, seeds 5 7 19 30 32"),
    ("KB-r07", SM, None,
     "func call_model_or_fail(s: StepState, pol: StepPolicy) -> StepDecision {\n  if pol.step_budget > 0 && s.step_idx >= pol.step_budget",
     "func call_model_or_fail(s: StepState, pol: StepPolicy) -> StepDecision {\n  if pol.step_budget > 0 && s.step_idx > pol.step_budget",
     "acceptance r07: >= becomes > in call_model_or_fail; must be red on provider-calls-exceed-budget, seed 244"),
    ("KB-r12", S, None,
     "c2_trace_wire_events(approved.trace, executed.emitted), executed.next_state);",
     "c2_trace_wire_events(approved.trace, executed.emitted), post.world_state);",
     "acceptance r12: the approved call's successor dropped; must be red on tool-dispatches-unbalanced, the members that dispatch"),
]


def find(i):
    for e in EDITS:
        if e[0] == i:
            return e
    sys.exit(f"unknown id {i}")


def locate(i, root):
    _, rel, anchor, old, new, _ = find(i)
    path = f"{root}/{rel}"
    src = open(path, encoding="utf-8").read()
    if old == new:
        sys.exit(f"{i}: a no-op")
    if anchor:
        if src.count(anchor) != 1:
            sys.exit(f"{i}: anchor occurs {src.count(anchor)} times, expected 1")
        a = src.index(anchor)
        w = src[a:a + 8000]
        if w.count(old) != 1:
            sys.exit(f"{i}: old text occurs {w.count(old)} times after the anchor, expected 1")
        pos = a + w.index(old)
    else:
        if src.count(old) != 1:
            sys.exit(f"{i}: old text occurs {src.count(old)} times, expected 1")
        pos = src.index(old)
    n = 0
    while n < min(len(old), len(new)) and old[n] == new[n]:
        n += 1
    return path, src, pos, src.count("\n", 0, pos + n) + 1


if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["list"]:
        for e in EDITS:
            print(f"{e[0]}\t{e[1]}\t{e[5]}")
    elif len(a) == 2 and a[0] == "check":
        for e in EDITS:
            _, _, _, line = locate(e[0], a[1])
            print(f"{e[0]}\tmatches once; edits {e[1]}:{line}")
    elif len(a) == 3 and a[0] == "apply":
        path, src, pos, line = locate(a[1], a[2])
        _, rel, _, old, new, _ = find(a[1])
        open(path, "w", encoding="utf-8").write(src[:pos] + new + src[pos + len(old):])
        print(f"{a[1]} applied at {rel}:{line}")
    else:
        sys.exit(__doc__)
