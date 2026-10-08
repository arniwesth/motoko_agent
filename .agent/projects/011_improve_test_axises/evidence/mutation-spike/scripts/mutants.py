#!/usr/bin/env python3
"""SPIKE ONLY — 011 §3.3 operator-feasibility spike. Never merges.

One single-site source mutant per stated rule. `apply <id>` makes exactly one
replacement and refuses if the old text does not occur exactly once (inside the
window after `anchor`, when one is given). `list` prints the table.

Predictions (`predict`, `gate`, `signature`) were written before any mutant ran;
see PLAN-spike-mutation-operator-feasibility.md. Do not edit them afterwards.
"""
import re
import sys

S = "src/core/session.ail"
T = "src/core/tool_phase.ail"
R = "src/core/recovery.ail"

MUTANTS = [
    dict(id="K0", file=S, kind="control: must survive",
         rule="(none) comment-only edit; forces the same recompile a real mutant does",
         old="let retry_event = StreamErrorRetry({ step: step_idx, error: e.message });",
         new="let retry_event = StreamErrorRetry({ step: step_idx, error: e.message }); -- spike K0 control",
         predict="SURVIVE", gate="", signature=""),
    dict(id="K1", file=S, kind="control: known killed (the demo's mutant, EXP-04 M2)",
         rule="session.ail:2356 — discarding a read's successor drops every read it carried",
         old="let r_base = ports.env_get(advance(r_retry.next_state, EnvRead)",
         new="let r_base = ports.env_get(advance(r_persist.next_state, EnvRead)",
         predict="KILL", gate="strict_replay",
         signature=r"\[discovery-env-read-under-recorded\][^\n]*'MOTOKO_RETRY_STREAM_ERROR'"),
    dict(id="M1", file=S, kind="recovery branch: session.c2_loop/stream_error_retry",
         rule="catalogue provider_error_retryable: step_idx advances by one, so the retry consumes step budget",
         anchor="let retry_event = StreamErrorRetry(",
         old="step_idx: step_idx + 1,", new="step_idx: step_idx,",
         predict="SURVIVE", gate="", signature=""),
    dict(id="M2", file=S, kind="recovery branch: session.c2_loop/stream_error_retry",
         rule="catalogue provider_error_retryable: the world advances to exchange.next_state",
         anchor="let retry_event = StreamErrorRetry(",
         old="world_state: capt.world,", new="world_state: st.world_state,",
         predict="KILL", gate="corpus_pr", signature=""),
    dict(id="M3", file=S, kind="recovery branch: session.c2_loop/provider_failure_finalize",
         rule="catalogue provider_error_non_retryable: the run finalizes as TermProviderFailure",
         old="step_idx, TermProviderFailure, e.message, started_at_ms, capt.trace",
         new="step_idx, TermSuccess, e.message, started_at_ms, capt.trace",
         predict="SURVIVE", gate="", signature=""),
    dict(id="M4", file=S, kind="recovery branch: session.c2_loop/empty_stop_finalize",
         rule="catalogue provider_empty_terminal_response: an EmptyStopFinalize record is appended to the returned trace",
         old="ledger_append(trace_with_decision, WireRecord(empty_event))",
         new="trace_with_decision",
         predict="SURVIVE", gate="", signature=""),
    dict(id="M5", file=S, kind="recovery branch: session.c2_loop/empty_stop_finalize",
         rule="catalogue provider_empty_terminal_response: ...and projected",
         old="let _ = ledger_emit(session_id, empty_event);", new="let _ = ();",
         predict="KILL", gate="corpus_pr",
         signature=r"(recovery branch 'session\.c2_loop/empty_stop_finalize'|empty_stop_finalize record\(s\) and exactly 1)"),
    dict(id="M6", file=S, kind="recovery branch: session.c2_loop/approval_denied",
         rule="session.ail:3585 — passing `st` instead of `post` is the freeze this class's assertion catches",
         old="started_at_ms, post, ledger_append(approved.trace, WireRecord(denied_event))",
         new="started_at_ms, st, ledger_append(approved.trace, WireRecord(denied_event))",
         predict="KILL", gate="corpus_pr", signature=""),
    dict(id="M7", file=T, kind="recovery branch: tool_phase.tool_outcome_message/ToolFailed",
         rule="catalogue ToolFailed: the typed fault is rendered into a tool-role message carrying fault_class",
         old="tool_fault_message(call, fault_class_tool_failed(), encode(jo([",
         new="tool_fault_message(call, fault_class_tool_deadline_exceeded(), encode(jo([",
         predict="KILL", gate="corpus_pr",
         signature=r"recovery branch 'tool_phase\.tool_outcome_message/ToolFailed'"),
    dict(id="M8", file=T, kind="recovery branch: tool_phase.tool_outcome_message/ToolCorrelationMismatch",
         rule="catalogue ToolCorrelationMismatch: the world answered an id nobody asked for (message carries expected_id and got_id)",
         old='kv("got_id", js(m.got_id))', new='kv("got_id", js(m.expected_id))',
         predict="SURVIVE", gate="", signature=""),
    dict(id="M9", file=R, kind="retry predicate (035 candidate row; verify_contract_mutations.sh's edit)",
         rule="recovery.ail:24 contract — a retry needs remaining_step_budget > 1",
         old="    && retry_enabled\n    && remaining_step_budget > 1\n",
         new="    && retry_enabled\n",
         predict="SURVIVE", gate="", signature=""),
    dict(id="M10", file=R, kind="retry predicate",
         rule="recovery.ail:24 contract — only a retryable error is retried",
         old="  {\n  retryable\n    && retry_enabled", new="  {\n  true\n    && retry_enabled",
         predict="KILL", gate="corpus_pr", signature=r"NON-RETRYABLE"),
    dict(id="M12", file=S, kind="world successor at a non-env handoff (the filesystem read in session_policy_init)",
         rule="session.ail:2356 — the fifth request is threaded exactly like the four env reads, for the same reason",
         anchor="func session_policy_init(",
         old="    next_state: r_limit.next_state\n", new="    next_state: r_headless.next_state\n",
         predict="KILL", gate="strict_replay", signature=r"\[discovery-under-recorded\]"),
]


def find(mid):
    for m in MUTANTS:
        if m["id"] == mid:
            return m
    sys.exit(f"unknown mutant {mid}")


def apply(mid):
    m = find(mid)
    src = open(m["file"], encoding="utf-8").read()
    start = 0
    if m.get("anchor"):
        if src.count(m["anchor"]) != 1:
            sys.exit(f"{mid}: anchor occurs {src.count(m['anchor'])} times, expected 1")
        start = src.index(m["anchor"])
        end = start + 6000
        window = src[start:end]
        if window.count(m["old"]) < 1:
            sys.exit(f"{mid}: old text not found in the window after the anchor")
        pos = start + window.index(m["old"])
    else:
        if src.count(m["old"]) != 1:
            sys.exit(f"{mid}: old text occurs {src.count(m['old'])} times, expected 1")
        pos = src.index(m["old"])
    out = src[:pos] + m["new"] + src[pos + len(m["old"]):]
    open(m["file"], "w", encoding="utf-8").write(out)
    line = src.count("\n", 0, pos) + 1
    print(f"{mid} applied at {m['file']}:{line}")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "apply":
        apply(sys.argv[2])
    elif len(sys.argv) >= 2 and sys.argv[1] == "ids":
        print(" ".join(m["id"] for m in MUTANTS))
    elif len(sys.argv) >= 2 and sys.argv[1] == "list":
        for m in MUTANTS:
            print("\t".join([m["id"], m["file"], m["predict"], m["gate"], m["signature"], m["rule"]]))
    else:
        sys.exit("usage: mutants.py apply <id> | ids | list")
