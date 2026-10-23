#!/usr/bin/env python3
"""Acceptance of 034 ADR-001 §2's properties P1-P3 by mutant (034 PLAN-001 W2.3): the one-edit
source mutants and the comment-only control.

    apply_mutant.py list
    apply_mutant.py check <root>          every edit's old text occurs exactly once; writes nothing
    apply_mutant.py apply <id> <root>     make that one replacement under <root>

`apply` refuses when the old text does not occur exactly once, and when the replacement would
change nothing. Every edit stays on the line it replaces, so no line below it moves (tool_phase.ail
carries attribution anchors by line number). Nothing here restores a file: the runner does that
with `git checkout --` and checks the hash. Sites are at `8c996274`.
"""
import sys

T = "src/core/tool_phase.ail"

# id, file, old, new, what the edit is
MUTANTS = [
    # p1a — P1, soundness. Every ToolFailed is rendered as if it failed BEFORE dispatch, so an
    # after-dispatch fault the world applied is answered `effects: none`.
    ("p1a", T,
     "tool_fault_message(call, fault_class_tool_failed(), failed_fault(f.after_dispatch), encode(jo([",
     "tool_fault_message(call, fault_class_tool_failed(), failed_fault(false), encode(jo([",
     "tool_phase.ail:293, tool_outcome_message renders `none` for every ToolFailed, after-dispatch included"),
    # p1b — P1, presence. `tool_fault_message` keeps the `fault` object, its kind and its note,
    # and drops `effects`. The refusal builders (denial, undecodable, deferral) do not go through
    # it and are untouched.
    ("p1b", T,
     "    kv(fault_key(), fault_to_json(fault)),",
     "    kv(fault_key(), jo([kv(\"kind\", match get(fault_to_json(fault), \"kind\") { Some(k) => k, None => js(\"\") }), "
     "kv(\"note\", match get(fault_to_json(fault), \"note\") { Some(n) => n, None => js(\"\") })])),",
     "tool_phase.ail:313, tool_fault_message drops `effects` from the fault object"),
    # p2 — P2. The message reads world truth: an after-dispatch ToolFailed whose effect the world
    # did NOT apply (the effect log did not grow across the dispatch) is rendered as before
    # dispatch, `none`; one that applied stays `unknown`. P1-sound by construction (`none` only
    # where nothing applied) and P1-present, so only the pair relation can see it.
    ("p2", T,
     "              msg: tool_outcome_message(call, execution.outcome),",
     "              msg: tool_outcome_message(call, match execution.outcome { ToolFailed(f) => ToolFailed({ f | after_dispatch: f.after_dispatch "
     "&& List.length(execution.next_state.effect_log) > List.length(handle_world.effect_log) }), o => o }),",
     "tool_phase.ail:515, the message reads `applied` off next_state's effect log"),
    # p3 — P3. The driver dispatches the same call again, once, when the first dispatch comes back
    # ToolDeadlineExceeded. Same invocation, same call id; the second execution's outcome and world
    # are what the fold continues with. No second dispatch-start record is emitted.
    ("p3", T,
     "            let execution = ports.tool_exec(advance(budget.next_state, EnvRead), invocation);",
     "            let execution0 = ports.tool_exec(advance(budget.next_state, EnvRead), invocation); "
     "let execution = match execution0.outcome { ToolDeadlineExceeded(_) => ports.tool_exec(advance(execution0.next_state, ToolExec), invocation), _ => execution0 };",
     "tool_phase.ail:507, the driver re-dispatches a call on ToolDeadlineExceeded"),
    # Control. A comment appended to the line p2 edits: a recompile, no behaviour change.
    ("K0", T,
     "              msg: tool_outcome_message(call, execution.outcome),",
     "              msg: tool_outcome_message(call, execution.outcome), -- 034 W2.3 K0 control",
     "tool_phase.ail:515, a comment-only edit on the dispatch site"),
]


def find(mid):
    for m in MUTANTS:
        if m[0] == mid:
            return m
    sys.exit(f"unknown id {mid}")


def locate(mid, root):
    _, rel, old, new, _ = find(mid)
    path = f"{root}/{rel}"
    src = open(path, encoding="utf-8").read()
    if old == new:
        sys.exit(f"{mid}: the replacement is a no-op")
    if "\n" in old or "\n" in new:
        sys.exit(f"{mid}: an edit must stay on its line")
    if src.count(old) != 1:
        sys.exit(f"{mid}: old text occurs {src.count(old)} times, expected 1")
    return path, src, src.index(old)


def line_of(src, pos):
    return src.count("\n", 0, pos) + 1


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd = argv[1]
    if cmd == "list":
        for m in MUTANTS:
            print(f"{m[0]}\t{m[1]}\t{m[4]}")
    elif cmd == "check":
        root = argv[2]
        for m in MUTANTS:
            path, src, pos = locate(m[0], root)
            print(f"{m[0]}\tOK\t{m[1]}:{line_of(src, pos)}\toccurs once\t{m[4]}")
    elif cmd == "apply":
        mid, root = argv[2], argv[3]
        path, src, pos = locate(mid, root)
        _, rel, old, new, what = find(mid)
        open(path, "w", encoding="utf-8").write(src[:pos] + new + src[pos + len(old):])
        print(f"{mid} applied at {rel}:{line_of(src, pos)}; {what}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
