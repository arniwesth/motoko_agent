#!/usr/bin/env python3
"""039 random-mutant pilot: the population, recomputed from the code's structure.

    population.py <root>     print the call graph's accounting; exit 1 if any function is
                             unaccounted for, or the population names one that is not reachable

THE RULE. The run under judgement is one traced run, and every traced run goes through
`session.run_v2_traced_from_seed`. The candidates are the functions of the four files that its
call graph reaches (a function applied, or passed as a value, counts as a call). A candidate is
in the population when it does at least one of:

  W  hands a world on: it takes a `WorldState` (or the loop state, or the ported provider, which
     carry one) and returns a value that carries the successor to the loop or out of the run;
  R  chooses the driver's response to an abnormal outcome: a failure, an exhausted budget or
     context, a retry, a suspension and its resume, an approval interruption, a refused tool
     call, a park and its wake, a judge's send-back.

Every other reachable function is excluded under one of the classes in EXCLUDED, each a
structural reason. Nothing here reads a test, a gate or a coverage record.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ailsrc  # noqa: E402

FILES = {
    "session": "src/core/session.ail",
    "recovery": "src/core/recovery.ail",
    "step_machine": "src/core/step_machine.ail",
    "tool_phase": "src/core/tool_phase.ail",
}
ROOT_FN = ("session", "run_v2_traced_from_seed")

MSG = "builds a message, an event, a warning or a string; chooses no response and hands no world"
PLUMB = "trace, journal or wire plumbing; its call sites in the population are mutated there"
HELP = "a projection, digest, telemetry, cost or status helper; no world, no recovery choice"
EXT = "the extension port layer: runs inside a hook's call; its successor reaches the loop only through the hook's returned token, adopted at sites in c2_loop"
UTIL = "a list or lookup utility; the decision that uses it is in the population"
ROUTE = "tool routing or argument parsing that is neither a refusal nor a world handoff"

EXCLUDED = {
    # session.ail
    "provider_api_model": HELP, "emit_json": PLUMB, "trace_event_enabled": PLUMB,
    "trace_sensitive_key": PLUMB, "trace_string_value": PLUMB, "trace_value_for_key": PLUMB,
    "trace_extra_kvs": PLUMB, "emit_trace_event": PLUMB, "schema_version": HELP,
    "motoko_commit": HELP, "millicents_to_usd": HELP, "event_type_from_projected": PLUMB,
    "event_extra_from_projected": PLUMB, "ledger_emit": PLUMB, "emit_pre_step_stages": PLUMB,
    "c2_chain_step": HELP, "c2_chain_base": HELP, "c2_chain_over": HELP, "c2_seed_digest": HELP,
    "initial_park_ordinal": HELP, "zero_totals": HELP, "runtime_status_count_one": HELP,
    "is_compaction_ai_ext_id": HELP, "runtime_status_counts": HELP, "runtime_status_json": HELP,
    "runtime_status_tool_message": MSG, "c2_decision_name": MSG, "c2_append_decision": PLUMB,
    "c2_trace_stage_records": PLUMB, "c2_trace_wire_events": PLUMB, "c2_emit_events": PLUMB,
    "c2_journal": PLUMB, "c2_append_step": PLUMB, "c2_cons_event": PLUMB,
    "c2_reverse_events": PLUMB, "c2_history_appended": PLUMB, "c2_ext_artifacts_digest": HELP,
    "c2_state_delta_event": MSG, "c2_tool_plan_calls": HELP, "c2_step_totals": HELP,
    "c2_step_state": HELP, "dbg_toolcall_json": MSG, "dbg_toolcalls_json": MSG,
    "dbg_message_json": MSG, "dbg_messages_json": MSG, "capture_failing_payload": PLUMB,
    "ext_ai_step": EXT, "tool_outcome_text": MSG, "tool_outcome_exit_code": HELP,
    "ext_ports_of": EXT, "ext_token_telemetry": HELP, "c2_add_step_totals": HELP,
    "c2_emit_cost_warning": MSG, "c2_done_step": HELP, "stream_chunk_event": MSG,
    "stream_chunk_events": MSG, "mk_run_summary": MSG, "mk_v2_ext_ctx": HELP,
    "messages_to_msgs": HELP, "count_system_prefix": HELP, "tool_calls_to_envelope_jsons": MSG,
    "json_field_str": HELP, "json_field_bool_true": HELP, "tool_messages_to_result_jsons": MSG,
    "policy_denied_message": MSG, "step_cost_millicents": HELP, "c2_final_state": HELP,
    "loop_token_telemetry": HELP, "c2_pending_context": HELP, "c2_pending_prefix": HELP,
    "c2_last_step": UTIL, "last_msg": UTIL, "park_request_id": MSG, "has_wait_id": UTIL,
    "remove_wait_id": UTIL, "remove_timer_id": UTIL, "loop_authored_tag": MSG,
    "wake_message": MSG, "park_drop_warning": MSG, "registered_new_wait": UTIL,
    "is_delegate_call_id": UTIL, "both_open_msgs": MSG, "witness_drain": PLUMB,
    # step_machine.ail
    "plan_native": HELP, "cost_cap_message": MSG, "checkpoint_summary": MSG,
    "mk_checkpoint_plan": MSG, "should_checkpoint": HELP,
    # tool_phase.ail
    "denial_message": MSG, "msg_get_str": UTIL, "is_scratchpad_tool_name": ROUTE,
    "scratchpad_extension_active": ROUTE, "scratchpad_extension_active_rec": ROUTE,
    "scratchpad_cells_arg": ROUTE, "delegated_deferred_message": MSG,
    "emit_scratchpad_result_if_present": PLUMB, "parse_timeout_ms": ROUTE,
    "tool_outcome_message": MSG, "tool_fault_message": MSG,
    "undecodable_arguments_message": MSG, "invalid_request_message": MSG,
}
# A name the call graph picks up from a local variable of the same spelling, not a call.
NOT_A_CALL = {("tool_phase", "call"): "a test fixture named `call`; the graph meets the local variable `call`, not this function"}


def load(root):
    F, SRC, TOK, IMP = {}, {}, {}, {}
    for m, p in FILES.items():
        s = open(os.path.join(root, p), encoding="utf-8").read()
        SRC[m], TOK[m], IMP[m] = s, ailsrc.tokens(s), ailsrc.imports(s)
        for f in ailsrc.functions(s, p):
            F[(m, f.name)] = f
    return F, SRC, TOK, IMP


def reachable(root):
    F, SRC, TOK, IMP = load(root)
    names = {k[1] for k in F}

    def resolve(m, name):
        if (m, name) in F:
            return (m, name)
        for om, ns in IMP[m].items():
            if om in FILES and name in ns and (om, name) in F:
                return (om, name)
        return None

    graph = {k: [r for r in (resolve(k[0], c) for c in ailsrc.calls_in(SRC[k[0]], f, names, TOK[k[0]])) if r]
             for k, f in F.items()}
    seen, stack = [], [ROOT_FN]
    while stack:
        x = stack.pop()
        if x not in seen:
            seen.append(x)
            stack.extend(graph[x])
    return F, seen


def population(root):
    """[(file, function)] from population.tsv beside this script's directory."""
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(here, "population.tsv"), encoding="utf-8")][1:]
    return [(r[0], r[1], r[2]) for r in rows if r and r[0]]


def main(root):
    F, seen = reachable(root)
    pop = population(root)
    popkeys = {(next(m for m, p in FILES.items() if p == f), n) for f, n, _ in pop}
    bad = 0
    for k in sorted(seen, key=lambda k: (k[0], F[k].line)):
        f = F[k]
        if k in popkeys:
            status = "IN"
        elif k in NOT_A_CALL:
            status = "OUT\t" + NOT_A_CALL[k]
        elif k[1] in EXCLUDED:
            status = "OUT\t" + EXCLUDED[k[1]]
        else:
            status = "UNACCOUNTED"
            bad += 1
        print(f"{FILES[k[0]]}\t{k[1]}\t{f.line}-{f.end_line}\t{status}")
    for k in sorted(popkeys - set(seen)):
        print(f"{FILES[k[0]]}\t{k[1]}\t-\tNAMED BUT NOT REACHABLE")
        bad += 1
    print(f"# reachable={len(seen)} in_population={len(popkeys & set(seen))} unaccounted_or_unreachable={bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
