# NOTE — Q1: Event-Subject Pass over the Ledger-Trace Record Kinds

Date: 2026-08-08
Status: First pass, desk work against source. Answers ADR-001 (010) Q1. Rows marked **probe** need a construction-site/behavior read before the table is committed; everything else is grounded in the vocabulary source and construction-site grep.

## Headline answers

1. **Multi-subject events are real and common.** Roughly half the rows resolve to a *set* of subjects, almost always `{owning mechanism} ∪ {payload-named tool/extension module}`. The event-subject table must map each key to a **subject-set rule**, not a module.
2. **Three rule kinds cover every row** (this fixes `activity.rule_kind`):
   - `fixed` — subject set is constant for the variant;
   - `payload_routed` — subject set depends on payload fields (`tool`, `ext_id`, `source`, `tool_calls[]`);
   - `correlated` — subject requires joining a sibling event (exactly one case: `V2ToolDispatchComplete` has no `tool` field and must be joined to its `V2ToolDispatchStart` by `id`).
   Plus `unattributed` as the fail-open rendering state.
3. **The table has 30 keys, not 28.** The returned trace is `[LedgerRecord]` where `LedgerRecord = WireRecord(LedgerEvent) | CompactionStageRecord | DecisionRecord` (`phase_vocab.ail:594`). The 28 LOGICAL event variants cover only `WireRecord`; `CompactionStageRecord` and `DecisionRecord` need rules too. The 6 DISPLAY-ONLY variants have `reaches_trace_today: false` and need no rules.
4. **An auxiliary mapping is required:** tool name → handler module, for every `payload_routed` rule over `tool`/`tool_calls`. `tool_catalog.tools()` (native) plus the extension registry (ext-served tools) are the sources. This is a small derived table, refreshed with the graph.
5. **The append chokepoint exists and is named:** `phase_vocab.ledger_append` (`phase_vocab.ail:604`) is the single append function. This strengthens ADR-001/D5's ordinal join: append spans in a semantic trace are exactly the `ledger_append` frames.
6. **The two D6.4 gaps are `ScratchpadResult` and `SessionSuspend`** (LOGICAL, `reaches_trace_today: false`). The overlay will simply never see them until 009 closes the gaps; their rows are written anyway so closure needs no table change.

## The pass

Subjects are module slugs under `src/core/` unless noted. "Emitter ≠ subject" holds throughout: 26 of 28 variants are *constructed* in `session.ail` or projected in `phase_vocab.ail`; construction site was used as evidence, never as the answer.

### WireRecord — 28 LOGICAL variants

| # | Variant | Subject set | Rule kind | Notes |
|---|---|---|---|---|
| 1 | ProviderCallPrepared | model_phase | fixed | Call assembly; payload digests are replay identity (009/D8) |
| 2 | ScratchpadResult | tool_phase + env_client | fixed | **settled**: `env_client.exec_scratchpad_cell` (env_client.ail:118) executes cells; always the scratchpad tool → fixed, not payload_routed. D6.4 gap — never in trace today |
| 3 | RunSummary | session | fixed | Terminal record; appended by c2_finalize |
| 4 | NativeToolDenied | tool_phase + tool(`tool`) | payload_routed | Approval denial |
| 5 | ToolPending | tool_phase + tool(`tool`) | payload_routed | |
| 6 | ExtToolHandled | ext(`tool` → registry) + tool_phase | payload_routed | Which ext served is 009/D5 coverage evidence |
| 7 | DelegatedToolDeferred | tool_phase + tool(`tool`) | payload_routed | Records a non-execution |
| 8 | V2ToolDispatchStart | tool_phase + tool(`tool`) | payload_routed | |
| 9 | V2ToolDispatchComplete | tool_phase + tool(via Start) | **correlated** | No `tool` field; join to Start by `id`. The one correlated row |
| 10 | Dp7VerifierRejected | session (dp7 gate) + ext/runtime | fixed | **settled**: `run_dp7_verifier` (session.ail:1713, `!{Process}`) runs the verifier via ExtRuntime; payload does not name the ext |
| 11 | CostExhausted | cost_phase | fixed | |
| 12 | CompactionExhausted | compaction | fixed | Terminal cause, not a stage outcome |
| 13 | ThinkingStreamStart | model_phase | fixed | Stream bracket |
| 14 | ThinkingStreamEnd | model_phase | fixed | `status` discriminates completed/errored |
| 15 | StreamErrorRetry | model_phase | fixed | |
| 16 | ProviderResult | model_phase | fixed | The one variant constructed *in* its subject (`model_phase.ail`) |
| 17 | ExtInterceptHandled | ext(`tool` → registry) + tool_phase | payload_routed | Projection is lossy (no stream_id/id) — recorded in vocabulary, harmless here |
| 18 | HybridBashExtracted | session (hybrid path) + parse | fixed | **settled**: `parse.extract_bash` (parse.ail:118) called from session's c2 loop |
| 19 | DoneEvent | session | fixed | Append-before/project-after site (WI-A14 finding) |
| 20 | EmptyStopFinalize | session | fixed | Terminal path |
| 21 | ExtSolverFeedback | ext/runtime + solver ext | fixed | **settled**: `dispatch_solver_candidate` (ext/runtime.ail:453); concrete solver ext registry-resolved, not in payload |
| 22 | PersistNudge | session | fixed | **settled**: `should_inject_persist_nudge` in session's loop, policy-driven; no hook_phase involvement |
| 23 | NativeToolCalls | model_phase + tools(`tool_calls[]`) | payload_routed | Subject set includes a **list** of tools — first set-valued payload |
| 24 | NativeToolResults | tool_phase + tools(`results[]`) | payload_routed | Set-valued |
| 25 | SessionSuspend | session | fixed | **settled**: emitted at session.ail:3127; supervisor not implicated at the emission site. D6.4 gap — never in trace today |
| 26 | ErrorEvent | route on `source` | payload_routed | Subject entirely payload-determined; needs a `source` → module map |
| 27 | CheckpointTaken | phase_vocab (checkpoint seam) | fixed | **settled**: constructed inside `phase_vocab.checkpoint` (phase_vocab.ail:263) — **corrects the "phase_vocab is projection-only" heuristic**: it also owns the checkpoint seam |
| 28 | StreamDelta | tool_stream_phase | fixed | Constructed there; model_phase adjacency — confirm during probe |

### Non-wire record kinds — 2 additional rows

| # | Record kind | Subject set | Rule kind | Notes |
|---|---|---|---|---|
| 29 | CompactionStageRecord | compaction + ext(`ext_id`) | payload_routed | The logical counterpart of the 3 DISPLAY-ONLY compaction events |
| 30 | DecisionRecord | session (step decision) | fixed | **settled**: appended by `c2_append_decision` (session.ail:582); `decision` ∈ {CallModel, RunTools, AwaitApproval, InjectUserMessage, TakeCheckpoint, Finalize, Fail} (`c2_decision_name` over `StepDecision`, defined phase_vocab.ail:448). One subject; the 7 values are useful as *view filters*, not for routing |

### Needing no rules

DISPLAY-ONLY (6): CompactionApplied, ExtCompactionRejected, ExtensionDiagnostic, CostWarning, SessionStart, TotalsUpdated — all `reaches_trace_today: false`; none can appear in the overlay's input.

## Tally (final, after probe resolutions)

- fixed: **19** · payload_routed: **10** · correlated: **1** (= 30 keys; the first-pass tally of 15/12/1 covered only the 28 event variants and misfiled rows 2 and 30, both settled as fixed)
- probe-flagged: **0 remaining** — all 8 settled same-day by construction-site reads (see rows 2, 10, 18, 21, 22, 25, 27, 30)
- multi-subject rows: **15** of 30 (2, 4–10, 17, 18, 21, 23, 24, 26, 29) → **the viewer must render subject-set glow** (split or duplicate; a design choice for P4, not a data problem)

One heuristic correction worth keeping: **`phase_vocab` is not projection-only** — it owns the checkpoint seam (`checkpoint`, CheckpointTaken construction) and defines `StepDecision`. "Constructed in phase_vocab ⇒ not a subject" is false for row 27.

## Q3 probe results (same day) — semantic-trace topology

Probed by running `scripts/dst/discovery_dst.ail` under `--emit-trace jsonl` at both tiers (AILANG v0.33.0):

1. **DST scripts require `--caps Trace` regardless of `--emit-trace`** — the wire emission path is an AILANG `Trace` effect. (Makefile invocations show `--caps IO` only; either stale or version drift — not chased here.)
2. **The wire projection already streams to stdout during runs** — 364 `schema_version: 1` JSON lines in the baseline run; this is what the Makefile's `grep -v '^{'` strips. It is the *emission-witness* side, not the returned trace (no non-wire record kinds, no run identity, parity with the returned trace is a checked invariant, not an identity) — so D9's returned-trace export stands; capturing stdout is recorded as a considered-and-rejected alternative.
3. **One `ailang run` process = one semantic trace, but one DST script ≠ one driver run**: the partial capture showed ≥6 `run_summary` events all under `session_id: session_0` — existing scripts run many driver runs per process with a shared session id. The ordinal join therefore needs per-run segmentation, OR trace-on-demand runs **one seed per process** — which was already the preferred volume mitigation, and is now also the topology fix. D9's exporter should be built one-profile-one-seed-per-invocation for the same reason.
4. **The volume risk is empirical, not hypothetical**: with `--emit-trace` at *either* tier the run is SIGKILLed (exit 137) before the buffered trace flushes; the baseline without tracing completes cleanly (exit 0). Semantic tracing of a full DST script is not currently viable — the upgrade path needs upstream **streaming/incremental trace export** (or per-module filtering) before it can run against real drivers. Filed as the concrete upstream ask.

## Consequences fed back into ADR-001 (010)

- Q1 is **answered**: subject-set rules, three rule kinds + unattributed, 30 keys.
- New auxiliary artifact: **tool→module map** (from `tool_catalog` + ext registry), a dependency of every `payload_routed` rule.
- `activity.variant` must be record-kind aware (`WireRecord:<variant>` | `CompactionStageRecord` | `DecisionRecord`).
- `phase_vocab.ledger_append` chokepoint recorded in support of D5's ordinal join.
- The named gaps (ScratchpadResult, SessionSuspend) replace the anonymous "2 of 28" in the ADR.
