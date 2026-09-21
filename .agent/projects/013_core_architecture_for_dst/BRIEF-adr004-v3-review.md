# Brief: adversarial review of ADR-004 v3 (journal as evaluation source, married to DST strict replay)

Repo: /workspaces/motoko_agent, branch `arniwesth/013-plan003-and-herdr`, HEAD `d5edebf`.
Read-only review: edit no file under the repo except the one review document you write; run no
commit; run no `make dst` sweep, no replay, no prototype run — memory is contended (the rule in
`HANDOFF-2026-09-13-plan001-p2d-sweep-pending.md` §2: aggregate `/sys/fs/cgroup/memory.current`
must stay well under 12 GiB and nothing heavy may run beside a sweep). `ailang check` on a
script and targeted Python reads of existing JSONL, TSV and profile files are fine. Other agents
share this working tree; make no claim about uncommitted changes; cite HEAD with
`git show d5edebf:<path>` or the working tree where it equals HEAD. You are inside herdr
(`HERDR_ENV=1`); do not open, close or prompt any pane or agent. Temporary evidence goes under
`/tmp/claude-1001/-workspaces-motoko-agent/0dc4f7fe-4912-46cb-8ed0-5a4e6fc6a2b5/scratchpad/codex-review/` (create it).

## Under review

`.agent/projects/013_core_architecture_for_dst/ADR-004-journal-as-evaluation-source.md` —
Proposed, **v3**, unreviewed. Eight decisions D1–D8. Give a verdict per decision — ACCEPT /
ACCEPT WITH CORRECTIONS / RETURN — with the reason, in the shape of
`REVIEW-adr004-v2-verdicts-codex.md` in the same directory (read it first: it is the standard
this review is held to — every coordinate re-read, every number re-derived, no verdict from
prose alone).

v3 restructures v2 around one new option, **O7**: build a `WorldState` from the journal segment
plus a host-log excerpt, run the parent once through `run_v2_session_traced` as
`PortedWorld(recording ports with two evaluator seams, world)` with `step_budget = N`, and treat
that run's interaction log as an `ExecutionProgram` that every candidate strict-replays under the
harness's own `world_state_of`, `reconstitution_balance`, `strict_replay_findings` and
`check_discovery`. The review's central question is whether that marriage is sound at HEAD.

## Inputs the ADR relies on (read them; check the ADR against them, not the reverse)

- `REVIEW-adr004-verdicts-codex.md` (v1) and `REVIEW-adr004-v2-verdicts-codex.md` (v2, four
  blockers, eight required changes) — v3 claims to fold all eight; check each.
- `REVIEW-adr004-v2-verdicts-fable.md` — the marriage argument, its §1 table, §3 gaps and its
  two same-day corrections (the variant is needed; `encode_artifact` cannot persist real content).
- `ADR-003-session-journal-and-resume.md` v6.1: O2, D1, D2 (the typed suspension), D4 (the fold,
  `JournalFold`), retraction 4. `ADR-001` D2. PLAN-003 §0.6.
- `design_docs/planned/m-motoko-dst-recursive-self-improvement.md` (the verifier-trust rule).
- Code at HEAD: `src/core/dst_program.ail` (`InitialWorld`, `ExecutionProgram`,
  `validate_program`, `check_bounds`), `dst_replay.ail` (`world_state_of`, `script_of`,
  `tools_of`, `ext_effects_of`, `approvals_of`, `reconstitution_balance`,
  `strict_replay_findings`, `ReplayMismatch`, `ReplayRefusal`), `dst_interaction.ail`
  (`Interaction`, `IdentityBody`, `identity_projection`), `dst_discovery.ail`
  (`check_discovery`, `class_balance`, `driver_env_keys`, `DiscoveryWitness`),
  `dst_persistence.ail` (`encode_body`, `program_digest`, `scan_program`, `encode_artifact`,
  `decode_artifact`, `load_program`, escaping), `dst_secrets.ail` (`scan_text`,
  `longest_opaque_run`, `redact_interactions`), `dst_profile.ail` (`ExecutionManifest`,
  `validate_manifest`, `driver_only`), `step_machine.ail` (`call_model_or_fail`, `decide`),
  `ports.ail` (`world_tool`, `scripted_tool_outcome`, `recording_tool`, `record_interaction`,
  `provider_outcome_record`, the outcome codecs, `ScriptedStep`, `ScriptedTool`, `ToolOutcome`),
  `test/stub_step.ail` (`StepProvider`, `recording_model_step`, `recording_ports`,
  `scripted_to_step_result`, the export list at the top), `session.ail` (`ported_provider`,
  `c2_initial_state_with_counts`, `c2_suspend`, `TracedSessionResult`, `run_v2_session_traced`,
  `run_v2_from_messages_traced_with_policy_and_counts`, `c2_add_step_totals`,
  `runtime_status_json`), `journal.ail` (`all_entry_types`, `fold_journal`, `messages_of_json`),
  `dst_invariants.ail` (`JournalFold`), `scripts/dst/strict_replay_dst.ail` (`run_recording`,
  `base_world`, `program_of`, `run_scenario`, `discovered_manifest`),
  `scripts/dst/ledger_parity_dst.ail` (`frame_ordinal0`), `src/core/test/scripted_ports.ail`.
- Evidence: the host log `.motoko/logfile/session_1789244855221-63164319c7d765ff.jsonl`; the
  prototypes and stored outputs/profiles in `/workspaces/motoko_agent-mem` (`scripts/dst/mem_journal_replay.ail`,
  `.motoko/memfix/`); the journal snapshot the prototype's `replay_input.json` was built from.

## Questions the review must answer, beyond per-decision verdicts

1. **O7 soundness.** Can the interaction log of a `PortedWorld` run over a journal-built world be
   an `ExecutionProgram` that `world_state_of` reconstitutes and `strict_replay_findings` grades?
   Check `script_of`/`tools_of`/`ext_effects_of`/`approvals_of` against what D2's seams record;
   check `validate_program` and `validate_manifest(m, driver_only())` accept a program with
   `generator_id: "journal_admission"`, observed bounds and an empty registry; check
   `check_discovery`'s witness expectations (env-read counts, the families it requires) hold for a
   run through `run_v2_session_traced` with no extensions.
2. **The end.** Verify that `step_budget = N` yields exactly N provider calls and a typed
   `RunSuspended` with `final` populated; that `decide`'s arm order makes D1's
   `NonReplayableLastFinish` rule complete (which finish reasons inject or park before the budget
   test; `hybrid_bash`, `await_approval`, `dp7_*`, `persist_nudge`, `solver_feedback`,
   `open_waits`); and that `BudgetPlan` (`budget.total`/`solver`), `max_cost_millicents` or the
   checkpoint policy cannot end the run earlier under the recorded `BootInputs`.
3. **The seams.** Can `eval_model_step` and `eval_tool_exec` be composed from **exported** core
   pieces as D2 claims? List which of `record_interaction`, `provider_outcome_record`,
   `scripted_to_step_result`, `scripted_step_faults`, `scripted_step_ai_error`, `scripted_chunks`,
   `play_chunks`, `world_tool`, `encode_tool_outcome`, `tool_outcome_record`,
   `encode_exhausted_provider_outcome` are exported at HEAD and from which module. Does a wider
   `request_projection` break anything (`identity_projection`, `HarnessFailure`, persistence
   escaping of `=`/`<`/newlines, `max_payload_bytes`, `scan_interactions`)?
4. **The variant.** Confirm every exhaustive `StepProvider` match at HEAD (`ported_provider`,
   `frame_ordinal0`, `test/scripted_ports.ail`, any other) and whether adding `PortedWorld` moves
   any anchor `tools/anchors.sh` or `derive.py` pins (see the note at `stub_step.ail` import line
   about `:203`), any golden, or any DST gate.
5. **Seed in snapshot, not program.** Is D2's choice (b) sound, or does `world_state_of`,
   `reconstitution_balance`, `validate_initial_world` or persistence assume a self-contained
   program in a way that breaks? What would `execution-program/4` with a `[Message]` field cost?
6. **Scan policy.** Confirm or refute the claim that `OpaqueHighEntropy` fires on an ordinary
   repository path, by running the `longest_opaque_run` rule (a Python re-implementation is fine)
   over real tool outputs from the evidence session; say whether the precise rules
   (`ProviderTokenLiteral`, `UrlUserinfo`, `PrivateKeyBlock`, `JsonWebToken`) would refuse an
   r2.1 program. Do not print conversation content as evidence; counts and sites only.
7. **Trust model.** Is D5's cooperative statement consistent with ADR-001, ADR-003 and the RSI
   doc? Does the path-refusal list plus the marker check add anything real? Is the compatibility
   patch for the `a6abda4` control consistent with "the candidate never touches evaluator paths"?
8. **Prior counts and nudges.** Verify `c2_initial_state_with_counts`; that no D3 check and no
   loop decision reads `cumulative`; that `run_v2_from_messages_traced_with_policy_and_counts` is
   unexported and what exporting a traced wrapper over it would cost.
9. **Cache served as zero.** Verify no observed projection or loop decision depends on
   `cache_read_input_tokens`/`cache_creation_input_tokens` under `max_cost_millicents: 0`
   (`c2_add_step_totals`, anything reading `totals.cache_*`, the `thinking` event, telemetry).
10. **Everything factually wrong** about the code, the numbers, or what the prior reviews said:
    list every one, with the correction.
11. **A cheaper design** than O7 that keeps the harness's checks, if one exists: describe it in
    at most 10 lines.

## Output

Write `.agent/projects/013_core_architecture_for_dst/REVIEW-adr004-v3-verdicts-codex.md` in the
shape of `REVIEW-adr004-v2-verdicts-codex.md`: header (date, HEAD, branch, subject, prior,
method, what you did not do); overall verdict; §1 disposition of the **fourteen v2→v3
retractions** and of the eight v2 required changes; §2 per-decision verdicts with one section
per decision; §3 the eleven questions; §4 claim audit (numbers, coordinates, new mechanisms);
"Required changes for v4" as a numbered list. Every claim carries a file:line at `d5edebf` or a
command and its output. When finished, reply with only the review file's path.
