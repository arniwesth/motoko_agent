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
    # --- Reach probes (tier 2). Diagnostic, not mutants: each makes the drawn site's statement (or,
    # where the site is an expression, the expression) fail with an integer division by zero when
    # it is evaluated, and changes nothing else. `scripts/probe-semantics-test.ail` showed a pure
    # `let _ = 1 / (n - n);` is evaluated although its value is unused. The divisor is an int in
    # scope minus itself, so nothing can fold it. A run that stays green with all 18 members never
    # evaluated the site; one that fails names the probe's file and line in its error, and the
    # count of JUDGEROW lines before it says whether a member (fewer than 18) or a control reached it.
    ("X-ctl", S, None,
     "c2_trace_wire_events(approved.trace, executed.emitted), executed.next_state);",
     "c2_trace_wire_events(approved.trace, executed.emitted), { executed.next_state | clock_ms: 1 / (tool_step_idx - tool_step_idx) });",
     "positive control: the approved-call handoff, which KB-r12 showed 12 members reach"),
    ("X-m01", S, "func run_v2_traced_from_seed(",
     "let started = provider.ports.clock_now(derived.next_state);",
     "let _ = 1 / (max_cost_millicents - max_cost_millicents); let started = provider.ports.clock_now(derived.next_state);",
     "m01's statement, session.ail:3834"),
    ("X-m02", S, None,
     "let appended = c2_history_appended(identity.run_id, step_idx, st.history_digest, false, last_msg(msgs_with_assistant) ++ [tool_msg]);",
     "let _ = 1 / (step_idx - step_idx); let appended = c2_history_appended(identity.run_id, step_idx, st.history_digest, false, last_msg(msgs_with_assistant) ++ [tool_msg]);",
     "m02's statement, session.ail:3616 (InterceptHandled)"),
    ("X-m03", T, None,
     "    AllowAfterTimeout => true,",
     "    AllowAfterTimeout => { let _ = 1 / Str.length(\"\"); true },",
     "m03's arm, tool_phase.ail:188"),
    ("X-m04", T, None,
     "let budget = ports.env_get(advance(started.next_state, ClockRead), \"MOTOKO_TOOL_TIMEOUT_MS\", \"0\");",
     "let _ = 1 / (step_idx - step_idx); let budget = ports.env_get(advance(started.next_state, ClockRead), \"MOTOKO_TOOL_TIMEOUT_MS\", \"0\");",
     "m04's statement, tool_phase.ail:500"),
    ("X-m05", S, None,
     "let ctx = mk_v2_ext_ctx(task, tool_step_idx, model, workdir, env_url, budget, c2_pending_context(post),",
     "let _ = 1 / (tool_step_idx - tool_step_idx); let ctx = mk_v2_ext_ctx(task, tool_step_idx, model, workdir, env_url, budget, c2_pending_context(post),",
     "m05's statement, session.ail:3243"),
    ("X-m06", S, None,
     "let trace_with_history = c2_journal(session_id, trace_after_model, appended.events);",
     "let _ = 1 / (step_idx - step_idx); let trace_with_history = c2_journal(session_id, trace_after_model, appended.events);",
     "the statement before m06's, session.ail:3667, in the same block with no branch between"),
    ("X-m07", S, None,
     "let executed = execute_allowed_tool_call(post.provider, post.world_state, rt, ctx,",
     "let _ = 1 / (tool_step_idx - tool_step_idx); let executed = execute_allowed_tool_call(post.provider, post.world_state, rt, ctx,",
     "m07's statement, session.ail:3258"),
    ("X-m08", S, None,
     "let msg = \"approval requested without pending approval state\";",
     "let _ = 1 / (st.step_idx - st.step_idx); let msg = \"approval requested without pending approval state\";",
     "the None arm holding m08, session.ail:3212"),
    ("X-m09", T, None,
     "let _ = emit(invalid_event);",
     "let _ = 1 / (step_idx - step_idx); let _ = emit(invalid_event);",
     "m09's statement, tool_phase.ail:515"),
    ("X-m10", T, None,
     "let r = msg_get_str(obj, \"reason\");",
     "let _ = 1 / (Str.length(raw) - Str.length(raw)); let r = msg_get_str(obj, \"reason\");",
     "the deny branch holding m10, tool_phase.ail:90"),
    ("X-m11", S, None,
     "let trace_with_retry = ledger_append(capt.trace, WireRecord(retry_event));",
     "let _ = 1 / (step_idx - step_idx); let trace_with_retry = ledger_append(capt.trace, WireRecord(retry_event));",
     "m11's statement, session.ail:3523"),
    ("X-m12", T, None,
     "let _ = emit(deferred_event);",
     "let _ = 1 / (step_idx - step_idx); let _ = emit(deferred_event);",
     "m12's statement, tool_phase.ail:476"),
    ("X-m13", T, None,
     "let denial_msg = denial_message(call, reason);",
     "let _ = 1 / (step_idx - step_idx); let denial_msg = denial_message(call, reason);",
     "the policy-Deny arm holding m13, tool_phase.ail:636"),
    ("X-m14", S, None,
     "let next_msgs = st.msgs ++ [msg];",
     "let _ = 1 / (st.step_idx - st.step_idx); let next_msgs = st.msgs ++ [msg];",
     "m14's statement, session.ail:3052"),
    ("X-m15", T, None,
     "let scratch = emit_scratchpad_result_if_present(emit, \"step-${show(step_idx)}\", step_idx, call.id, result_env);\n    { msg: handled_tool_message(call.id, result_env), next_state: world,",
     "let _ = 1 / (step_idx - step_idx); let scratch = emit_scratchpad_result_if_present(emit, \"step-${show(step_idx)}\", step_idx, call.id, result_env);\n    { msg: handled_tool_message(call.id, result_env), next_state: world,",
     "the scratchpad arm holding m15, tool_phase.ail:421"),
    ("X-m16", T, None,
     "emitted: emitted ++ [pending_event],",
     "emitted: emitted ++ { let _ = 1 / (step_idx - step_idx); [pending_event] },",
     "m16's expression, tool_phase.ail:662"),
    ("X-m17", S, None,
     "    last_finish_reason: \"await_wake\" }",
     "    last_finish_reason: { let _ = 1 / (step_idx - step_idx); \"await_wake\" } }",
     "c2_await_wake_state's body, holding m17, session.ail:2761"),
    ("X-m18", S, None,
     "ports: ext_ports_of(ports, seen.world, env_url),",
     "ports: ext_ports_of(ports, { seen.world | clock_ms: 1 / (world.ordinal - world.ordinal) }, env_url),",
     "m18's argument, session.ail:4574"),
    ("X-m19", T, None,
     "let _ = emit(denied_event);",
     "let _ = 1 / (step_idx - step_idx); let _ = emit(denied_event);",
     "m19's statement, tool_phase.ail:635"),
    ("X-m20", T, None,
     "let resolution = dispatch_resolution(handle_world.process_limits, call.name, envelope.arguments);",
     "let _ = 1 / (step_idx - step_idx); let resolution = dispatch_resolution(handle_world.process_limits, call.name, envelope.arguments);",
     "m20's statement, tool_phase.ail:491"),
    ("X-m21", S, None,
     "let _ = ledger_emit(session_id, prepared_event);",
     "let _ = 1 / (step_idx - step_idx); let _ = ledger_emit(session_id, prepared_event);",
     "m21's statement, session.ail:3458"),
    ("X-m22", S, None,
     "let appended = c2_history_appended(identity.run_id, step_idx, st.history_digest, false, last_msg(msgs_with_assistant));\n  let trace_with_history = c2_journal(session_id, trace, appended.events);",
     "let _ = 1 / (step_idx - step_idx); let appended = c2_history_appended(identity.run_id, step_idx, st.history_digest, false, last_msg(msgs_with_assistant));\n  let trace_with_history = c2_journal(session_id, trace, appended.events);",
     "m22's statement, session.ail:2710 (also m24's block)"),
    ("X-m23", S, None,
     "          _ => true\n        })",
     "          _ => { let _ = 1 / (req.attempt - req.attempt); true }\n        })",
     "m23's arm, session.ail:2809"),
    ("X-m24", S, None,
     "  let trace_with_history = c2_journal(session_id, trace, appended.events);",
     "  let _ = 1 / (step_idx - step_idx); let trace_with_history = c2_journal(session_id, trace, appended.events);",
     "m24's statement, session.ail:2711"),
    ("X-m25", S, None,
     "let capt = if not e.retryable then { let capture = st.provider.env_get(stepped.world,",
     "let capt = if not e.retryable then { let _ = 1 / (step_idx - step_idx); let capture = st.provider.env_get(stepped.world,",
     "m25's statement, session.ail:3519 (the non-retryable branch)"),
    ("X-m26", SM, None,
     "    [] => Fail({ code: \"Internal\", message: \"approval requested without pending call\", retryable: false }),",
     "    [] => { let _ = 1 / (step_idx - step_idx); Fail({ code: \"Internal\", message: \"approval requested without pending call\", retryable: false }) },",
     "m26's arm, step_machine.ail:54"),
    ("X-m27", S, None,
     "let end_event = ThinkingStreamEnd({ step: step_idx, stream_id: stream_id, status: \"errored\" });",
     "let end_event = ThinkingStreamEnd({ step: step_idx, stream_id: stream_id, status: \"errored\" }); let _ = 1 / (step_idx - step_idx);",
     "after the statement before m27's, session.ail:3505, nothing between"),
    ("X-m28", S, None,
     "let named = ports.env_get(world, manifest_path_var(), \"\");",
     "let _ = 1 / (world.ordinal - world.ordinal); let named = ports.env_get(world, manifest_path_var(), \"\");",
     "m28's statement, session.ail:4552"),
    ("X-m29", S, "func run_v2_traced_from_seed(",
     "let session_id = derived.id; let booted = witness(",
     "let _ = 1 / (max_cost_millicents - max_cost_millicents); let session_id = derived.id; let booted = witness(",
     "m29's line, session.ail:3835"),
    ("X-m30", S, None,
     "  wake.request_id == req.request_id\n    && (match wake.outcome {",
     "  { let _ = 1 / (req.attempt - req.attempt); wake.request_id == req.request_id }\n    && (match wake.outcome {",
     "m30's conjunction, session.ail:2804"),
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
