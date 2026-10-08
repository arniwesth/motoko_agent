#!/usr/bin/env python3
"""Acceptance of ADR-003's rules (011 WI-4): the one-edit source mutants and controls.

    apply_mutant.py list
    apply_mutant.py check <root>          every edit's old text matches exactly once; writes nothing
    apply_mutant.py apply <id> <root>     make that one replacement under <root>

`<root>` is the scratch worktree, never the evidence worktree. `apply` refuses when the old text
does not occur exactly once (inside the 6000 characters after `anchor`, when one is given), and
when the replacement would change nothing. Nothing here restores a file: the runner does that with
`git checkout` and checks the hashes.

The text of rows 1 to 12 and of K0 is the spike's, from
`../../mutation-spike/scripts/mutants.py` (M1, M2, M3, M6, M9, K0), `mutants3.py` (T3),
`mutants4.py` (M3m) and `mutants5.py` (R1 to R5). Rows 13 and P3 and the two known-bad controls
are written here. Sites are at `ce9cb247`.
"""
import sys

S = "src/core/session.ail"
SM = "src/core/step_machine.ail"
R = "src/core/recovery.ail"
T = "src/core/tool_phase.ail"
INV = "src/core/dst_invariants.ail"
RETRY = "let retry_event = StreamErrorRetry("

# id, file, anchor, old, new, spike id, what the edit is
MUTANTS = [
    ("r01", S, None,
     "step_idx, TermProviderFailure, e.message, started_at_ms, capt.trace",
     "step_idx, TermSuccess, e.message, started_at_ms, capt.trace",
     "M3", "session.ail:3920, the failure finalize reports TermSuccess"),
    ("r02", S, None,
     'st.step_idx, TermSuccess, "", started_at_ms, published.trace, st.emissions, Ok(st.msgs)',
     'st.step_idx, TermProviderFailure, "", started_at_ms, published.trace, st.emissions, Ok(st.msgs)',
     "M3m", "session.ail:3402, the success finalize reports a failure reason"),
    ("r03", S, None,
     "step_idx, TermProviderFailure, e.message, started_at_ms, capt.trace",
     "step_idx, TermMaxSteps, e.message, started_at_ms, capt.trace",
     "R1", "session.ail:3920, the failure finalize reports TermMaxSteps"),
    ("r04", S, None,
     "st.step_idx, TermMaxSteps, info.message, started_at_ms",
     "st.step_idx, TermInternalFailure, info.message, started_at_ms",
     "R2", "session.ail:2789, the suspension reports TermInternalFailure"),
    ("r05", S, RETRY,
     "step_idx: step_idx + 1,", "step_idx: step_idx,",
     "M1", "session.ail:3887, the retry keeps step_idx"),
    ("r06", S, RETRY,
     "step_idx: step_idx + 1,", "step_idx: step_idx + 2,",
     "R3", "session.ail:3887, the retry adds two"),
    # The spike's R5 took the first match in the window after `func call_model_or_fail(`. The same
    # predicate is also at :145, in `decide`'s park arm, so the old text here carries the function
    # header: one match, and the same one-character edit at :103.
    ("r07", SM, None,
     "func call_model_or_fail(s: StepState, pol: StepPolicy) -> StepDecision {\n  if pol.step_budget > 0 && s.step_idx >= pol.step_budget",
     "func call_model_or_fail(s: StepState, pol: StepPolicy) -> StepDecision {\n  if pol.step_budget > 0 && s.step_idx > pol.step_budget",
     "R5", "step_machine.ail:103, >= becomes >"),
    ("r08", R, None,
     "    && retry_enabled\n    && remaining_step_budget > 1\n",
     "    && retry_enabled\n",
     "M9", "recovery.ail:28, remaining_step_budget > 1 is dropped"),
    ("r09", S, RETRY,
     "world_state: capt.world,", "world_state: st.world_state,",
     "M2", "session.ail:3892, the retry keeps the pre-call world"),
    ("r10", S, None,
     "started_at_ms, post, ledger_append(approved.trace, WireRecord(denied_event))",
     "started_at_ms, st, ledger_append(approved.trace, WireRecord(denied_event))",
     "M6", "session.ail:3613, the denied-approval arm continues from st"),
    ("r11", S, None,
     "c2_finalize(st.provider, capt.world, session_id, model, st.totals, step_idx, TermProviderFailure",
     "c2_finalize(st.provider, stepped.world, session_id, model, st.totals, step_idx, TermProviderFailure",
     "R4", "session.ail:3920, capt.world becomes stepped.world"),
    ("r12", S, None,
     "c2_trace_wire_events(approved.trace, executed.emitted), executed.next_state);",
     "c2_trace_wire_events(approved.trace, executed.emitted), post.world_state);",
     "T3", "session.ail:3623, the approved call's successor is dropped"),
    ("r13", T, None,
     "emitted: [start_event, complete_event],",
     "emitted: [complete_event],",
     "new", "tool_phase.ail:505, start_event is left out of emitted"),
    ("P3", S, None,
     "ledger_append(ledger_append(trace_after_stages, WireRecord(start_event)), WireRecord(prepared_event))",
     "ledger_append(trace_after_stages, WireRecord(start_event))",
     "new", "session.ail:3861, the ProviderCallPrepared append is dropped"),
    # Controls.
    ("K0", S, None,
     "let retry_event = StreamErrorRetry({ step: step_idx, error: e.message });",
     "let retry_event = StreamErrorRetry({ step: step_idx, error: e.message }); -- spike K0 control",
     "K0", "session.ail:3880, a comment-only edit in the retry branch"),
    ("KB-D2", INV, None,
     'if code == "StepBudgetExhausted" then "max_steps"',
     'if code == "StepBudgetExhausted" then "error"',
     "control6.sh", "dst_invariants.ail:1812, StepBudgetExhausted implies error"),
    # Reach probes for the blind reviewer's two survivors. NOT rows of any table and not mutants
    # of a rule: each makes one line panic (integer division by zero) if it is ever evaluated, the
    # spike's `mutants3.py` P1 to P3 idea. A gate that stays green never evaluated the line.
    # X-reach-ctl is the positive control: the same poison on the approved-call handoff, which
    # row 12 showed ten members reach.
    ("X-reach-B2", T, None,
     "dispatch_tool_entries_with_builtin(ports, executed.next_state, rt,",
     "dispatch_tool_entries_with_builtin(ports, { executed.next_state | clock_ms: 1 / (step_idx - step_idx) }, rt,",
     "reach probe", "tool_phase.ail:615, B2's line panics if evaluated"),
    ("X-reach-B3", S, "func c2_dp7_rejected_state(",
     "step_idx: step_idx + 1,",
     "step_idx: step_idx + 1 / (step_idx - step_idx),",
     "reach probe", "session.ail:2985, B3's line panics if evaluated"),
    ("X-reach-ctl", S, None,
     "c2_trace_wire_events(approved.trace, executed.emitted), executed.next_state);",
     "c2_trace_wire_events(approved.trace, executed.emitted), { executed.next_state | clock_ms: 1 / (tool_step_idx - tool_step_idx) });",
     "reach probe", "session.ail:3623, row 12's line panics if evaluated (positive control)"),
    ("KB-D3", INV, None,
     "let here = if n > 1 && not contains_int(seen, s) then [DriverStepRepeated(s, n)] else [];",
     "let here = if n > 0 && not contains_int(seen, s) then [DriverStepRepeated(s, n)] else [];",
     "new", "dst_invariants.ail:1625, n > 1 becomes n > 0"),
]


# X-reach-B3 probes the line the blind row B3 edited, so it locates it as the blind applier does:
# the first occurrence after the anchor. (`c2_dp7_rejected_state`'s neighbour at :3033 builds the
# same field inside the 6000-character window.) No row of this acceptance's own table uses this.
FIRST_AFTER_ANCHOR = {"X-reach-B3"}


def find(mid):
    for m in MUTANTS:
        if m[0] == mid:
            return m
    sys.exit(f"unknown id {mid}")


def locate(mid, root):
    """Return (path, source, position) or exit with the reason the edit does not apply."""
    _, rel, anchor, old, new, _, _ = find(mid)
    path = f"{root}/{rel}"
    src = open(path, encoding="utf-8").read()
    if old == new:
        sys.exit(f"{mid}: the replacement is a no-op")
    if anchor:
        if src.count(anchor) != 1:
            sys.exit(f"{mid}: anchor occurs {src.count(anchor)} times, expected 1")
        start = src.index(anchor)
        window = src[start:start + 6000]
        if mid in FIRST_AFTER_ANCHOR:
            if old not in window:
                sys.exit(f"{mid}: old text does not occur in the window after the anchor")
        elif window.count(old) != 1:
            sys.exit(f"{mid}: old text occurs {window.count(old)} times in the window after the anchor, expected 1")
        pos = start + window.index(old)
    else:
        if src.count(old) != 1:
            sys.exit(f"{mid}: old text occurs {src.count(old)} times, expected 1")
        pos = src.index(old)
    return path, src, pos


def line_of(src, pos):
    return src.count("\n", 0, pos) + 1


def first_change(mid):
    """Offset into the old text of the first character the edit changes, so the line reported is
    the line edited and not the line the matched text starts on (r07 and r08 match from the line
    above)."""
    _, _, _, old, new, _, _ = find(mid)
    n = 0
    while n < min(len(old), len(new)) and old[n] == new[n]:
        n += 1
    return n


# --- The blind reviewer's rows -------------------------------------------------------------------
# Read from the reviewer's own file (`blind/blind-mutants.tsv`, columns id, file, anchor, old, new,
# ...), never retyped here. The reviewer's stated semantics, from its reply: `anchor` occurs once
# in the file and the edit replaces the FIRST occurrence of `old` after it; with no anchor, `old`
# itself occurs once. Anything else is refused.
def blind_rows(tsv):
    rows = []
    for i, line in enumerate(open(tsv, encoding="utf-8")):
        f = line.rstrip("\n").split("\t")
        if i == 0 or not line.strip():
            continue
        rows.append(dict(zip(["id", "file", "anchor", "old", "new", "rule_broken", "predict_red", "members", "why"], f)))
    return rows


def locate_blind(row, root):
    path = f"{root}/{row['file']}"
    src = open(path, encoding="utf-8").read()
    old, new, anchor = row["old"], row["new"], row["anchor"]
    if old == new:
        sys.exit(f"{row['id']}: the replacement is a no-op")
    if anchor:
        if src.count(anchor) != 1:
            sys.exit(f"{row['id']}: anchor occurs {src.count(anchor)} times, expected 1")
        start = src.index(anchor)
        if old not in src[start:]:
            sys.exit(f"{row['id']}: old text does not occur after the anchor")
        pos = src.index(old, start)
    else:
        if src.count(old) != 1:
            sys.exit(f"{row['id']}: old text occurs {src.count(old)} times, expected 1")
        pos = src.index(old)
    n = 0
    while n < min(len(old), len(new)) and old[n] == new[n]:
        n += 1
    return path, src, pos, line_of(src, pos + n)


def blind_main(a):
    rows = blind_rows(a[1])
    if a[0] == "check-blind" and len(a) == 3:
        for r in rows:
            _, src, _, line = locate_blind(r, a[2])
            print(f"{r['id']}\tmatches; edits {r['file']}:{line}\t(old text occurs {src.count(r['old'])} time(s) in the file)")
    elif a[0] == "apply-blind" and len(a) == 4:
        r = next((x for x in rows if x["id"] == a[2]), None)
        if r is None:
            sys.exit(f"unknown blind id {a[2]}")
        path, src, pos, line = locate_blind(r, a[3])
        open(path, "w", encoding="utf-8").write(src[:pos] + r["new"] + src[pos + len(r["old"]):])
        print(f"{r['id']} applied at {r['file']}:{line}")
    else:
        sys.exit("usage: apply_mutant.py check-blind <tsv> <root> | apply-blind <tsv> <id> <root>")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] in ("check-blind", "apply-blind"):
        blind_main(a)
    elif a == ["list"]:
        for m in MUTANTS:
            print("\t".join([m[0], m[1], m[5], m[6]]))
    elif len(a) == 2 and a[0] == "check":
        for m in MUTANTS:
            path, src, pos = locate(m[0], a[1])
            print(f"{m[0]}\tmatches once; edits {m[1]}:{line_of(src, pos + first_change(m[0]))}")
    elif len(a) == 3 and a[0] == "apply":
        mid, root = a[1], a[2]
        path, src, pos = locate(mid, root)
        _, rel, _, old, new, _, _ = find(mid)
        open(path, "w", encoding="utf-8").write(src[:pos] + new + src[pos + len(old):])
        print(f"{mid} applied at {rel}:{line_of(src, pos + first_change(mid))}")
    else:
        sys.exit(__doc__)
