# NOTE-009 — fifth live session: extended demo, assessment, and complexity levers (2026-09-07)

Date: 2026-09-07. Model: `openrouter/meta/muse-spark-1.3-contributor`. Profile: `default`
(`max_steps: 300`, 9 extensions active). Task path: `Run a longer demo of Motoko` →
`Run even longer` → guard-forced continuations (`progress-contract-guard`,
`empty-stop-guard`). No files modified, so no `check_core` gate was owed.
All observations below are read-only (`ReadFile`/`Search`) plus live
`MotokoRuntimeStatus` samples and one `model-catalog.json` read.

## 1. Session facts (measured)

- `step_budget: 300` throughout; `steps_executed_so_far` 4 → 10 → 17 over the
  session; `provider_calls_started/completed` in lockstep (10/10, then 17/17).
- `system_prefix`: stable, `count 1`, `chars 11189`,
  `digest sha256:28fc500c…` — unchanged across every sample (same digest as
  NOTE-008).
- `context_limit: 1048576` on every sample (NOT 0 — see finding 1).
- `last_sent.input_tokens` 41462 (3%) → 59538 (5%); `uncompacted_pending`
  calibrated 41462 → 59538, same pct. `note` field confirms the two numbers
  measure different windows by design (last compacted request vs full retained
  history before ephemeral compaction).
- `compaction.{stage_applied_total, stage_rejected_total, compaction_ai_applied}`:
  all 0 at close. No compaction occurred — correctly, at 3–5% usage.
- Cumulative `usage`: ~104k in / 10.7k out (step ~10) → ~464k in / 21.9k out
  (step ~17); `cache_read_input_tokens` ~404k of 464k (~87% cache reads).
  Cache attribution honest, same shape as NOTE-008 (~96% on a longer tour).

## 2. Finding 1 (closes a loop): NOTE-005 finding 1 / NOTE-008 finding 1 is FIXED

NOTE-005 (third session) found compaction silently and permanently disabled on
the default profile: a missing model-catalogue row resolved the limit to 0 and
every consumer read 0 as healthy (`usage_pct: 0` at ~230k real tokens).
NOTE-008 (fourth session) confirmed it as steady state on the same pinned model.

This session: `.motoko/model-catalog.json` now contains

```json
"openrouter/meta/muse-spark-1.3-contributor": 1048576
```

and every `MotokoRuntimeStatus` sample reports `context_limit: 1048576` with
matching `usage_pct` (3% → 5%). The exact failure mode — limit 0 rendering as
health — no longer reproduces on the default profile's pinned model.

Remaining gap (candidate gate, still open): no loud startup warning when a
limit resolves to 0 on a profile that installs compaction. The fix landed as a
data row, not as a guard. An uncatalogued model tomorrow re-enters the same
blind state. Suggested: `resolve_context_limit == 0 && compaction in
extensions.order` → `session_start` warning event (fail-open but loud), plus a
`catalog_check` CI target asserting every profile-pinned model has a row.

## 3. What was verified live (read-only tour)

| Item | Result |
|---|---|
| `src/core/rpc.ail` (364 lines) | thin entry post-M10b; `RunSettings`/`FirstTask`, config load, `ohmy_pi` fail-fast, `with_agents_context`, budget plan, `run_v2_with_conversation` |
| `src/core/agent_loop_v2.ail` (125 lines) | pure facade re-exporting `Session.*`; no logic |
| `src/core/session.ail` (3966 lines, was 3706 in NOTE-008) | sole ledger emitter, real effect row `{AI, Clock, Env, FS, IO, Net, Process, SharedMem, Stream, Trace, Rand}`, `c2_loop` tail-recursion over `decide` |
| `src/core/step_machine.ail` (437 lines) | pure `decide`; full table re-verified (hybrid_bash → pending → dp7_rejected → solver_feedback → persist_nudge → stop/dp7_approved/dp7_fail_open → stream_error/intercept_handled/tools_complete/user_injected → `call_model_or_fail`); max-steps discriminator single-literal in `dst_fault_catalogue` |
| `src/core/phase_vocab.ail` (1340 lines) | sealed `History = MkHistory`, head-prefix gate, digest, checkpoint chain; `StepState/StepPolicy/StepDecision`; ledger events + `RunSummary` |
| `src/core/tool_catalog.ail` (177 lines) | **correction to prior tour prose: 7 native tools, not 6** — inline tests assert `len(tools()) == 7`; 7th is `MotokoRuntimeStatus` (zero-arg introspection; description contains "how many steps have run" + "system prefix stayed stable"); `tools_with_extensions(rt) = tools() ++ collect_ext_schemas(...)` at :143 |
| `src/core/tool_contract.ail` (173 lines) | `ToolCallEnvelope/ToolResultEnvelope` (`Eq`); `result_to_model_json` sanitizes `cells/images/jsonOutputs`; `string/number/bool_field` fallbacks |
| `src/core/tool_phase.ail` (714 lines) | approval planning, policy/handle dispatch, world-threading via `ext_world` (sole opener), scratchpad WS loopback |
| `src/core/tool_runtime.ail` (1121 lines) | `needs_delegation_for_process`, `has_shell_tokens` (Z3 recall contract), wrap predicate |
| `src/core/model_phase.ail` (79 lines) | `result_delta` stores `last_estimated_input_tokens:sent_estimate` for affine calibration; `phase_from_result` builds `ProviderResult` |
| `src/core/hook_phase.ail` (24 lines) | `stage_record` maps `StageApplied/Rejected/Observed/Passed` |
| `src/core/cost_phase.ail` (67 lines) | `(in*in_rate+out*out_rate)/1e6`, cap, 50/75/90 warning thresholds, all with inline tests |
| `src/core/recovery.ail` (120 lines) | `should_retry_stream_error` with `ensures`, persist-nudge marker/count/inject |
| `src/core/ports.ail` (2574 lines) | port seams, `WorldState` threading (`PathRead` successor discipline, WI-D3 C1b fix), `Option`-import load-bearing comment, `FsNode` split-out rationale |
| `src/core/context_usage.ail` (169 lines) | char/4 estimate, `catalog_path` (`MOTOKO_MODELS_FILE` → catalog → `$MOTOKO_REPO`), `openrouter/` strip fallback |
| `src/core/compaction.ail` (163 lines) | `est=(sum+3)/4`, `exhaustion 95`, `output_allowance 65536`, `effective_input_limit`, `density 1235`, `affine_calibrate` (floor at raw, anchor-absent fallback) |
| `src/core/ext/runtime.ail` (1076 lines) | `init_runtime_with_config`, `join_order`, `hook_name` (`#idx` strip), full dispatch chain with successor world + holder stamp (WI-D24) |
| `src/core/ext/registry_generated.ail` (110 lines, GENERATED) | 18 registers, `resolve`, `parse_tokens` stamping `name#idx`, `normalize_registration` fail-closed exit 2, D7 empty-omitted warning; upstream generator unusable (5.x shape vs ABI 6.0) |
| `src/core/supervisor.ail` (53 lines) | `main`: CLI config, secret validation per prefix, `start_or_connect_backend`, `run_with_config` |
| `src/core/backend.ail` (90 lines) | health-before-spawn short-circuit (parallel-harness port fix), `backend_connect` vs `backend_start` events |
| `src/core/env_client.ail` (148 lines) | always-200 client, synthetic exit-1 on malformed body |
| `src/tui/src/runtime-process.ts` (790 lines) | spawn, JSONL parse, `DelegatedCall`, describe fns, `AgentEvent` union |
| `src/tui/src/env-server.ts` (1977 lines) | always-200 express app, claimcheck, scratchpad kernels/loopback/transcript |
| `src/tui/src/index.ts` (1071 lines) | env-server → runtime spawn → banner → `AgentUI` |
| `default/config.json` | pinned model `openrouter/meta/muse-spark-1.3-contributor`, `max_steps 300`, `hybrid:true, ohmy_pi:false`, 9-extension order, `verification: make check_core` |

No new core-loop defects. Headers match implementation (holder stamp, S12
noop transitions, `exit_code: -1` on no-op handles, `Pending` unused by
`repetition_guard`, guards-file asymmetry closed on the tool-calling half).

## 4. Assessment (operator question, answered in-session; agrees with NOTE-001 9/7/6)

Concept proven (typed tool-use loop, fail-closed registry, two-sided DST
grading, honest telemetry). Execution solid but expensive: comprehension tax
(56+ core modules, 3966-line driver, 2574-line ports, ten DST layers) plus the
now-fixed context-limit blind spot. Usability hinges on bounded entry points
(headless, smoke, DST scripts), not the interactive TUI (`make run` exceeds
the 35s tool ceiling — NOTE-008 finding 4, unchanged).

## 5. Complexity: what would lower it (operator question, answered in-session)

Delete first, then split, then harden types. Guardrails: keep DST isolated,
keep registry fail-closed, keep the max-steps discriminator single-literal,
keep schema-v1 ledger compatibility.

1. **Delete dead paths** — `ToolBackend.Delegated`, `needs_delegation_for_process`
   branches, `hybrid_bash` arm in `decide`, `agent_loop_v2` facade once callers
   move; move `stub_step`/`scripted_ports` out of the production import graph
   (`rpc.ail` importing `src/core/test/stub_step` — NOTE-003 measurement).
2. **Split the three giants** (no file >800 lines, CI line-count gate):
   `session.ail` → loop / finalize+run_summary / telemetry+calibration / event
   emitters; `ports.ail` → provider / fs / tool / record-codecs / world;
   `phase_vocab.ail` → history / ledger / transcript (PLAN-002 item 3 already
   names this split: events / state / policy).
3. **Replace stringly-typed control flow** — `last_finish_reason: string`
   (10+ compares) → `FinishReason` sum type with exhaustiveness checking;
   `BackendConfig.mode: string` → `BackendMode = None | ExternalHttp`.
4. **Single-source the tool catalog** — one table generating
   `tool_catalog` schemas + `tool_runtime` arg parsers + `tool_dispatch_adapter`
   envelopes (kills the 6-vs-7 drift class outright).
5. **Shrink default order + lazy load** — always-on `empty_stop_guard,
   repetition_guard, compaction_structural`; opt-in `exa_search, omnigraph, mcp,
   compose, herdr, microrag`; merge the two compaction exts into one with two
   strategies.
6. **Isolate the two external couplings** — one `transcript_seam.ail` owning both
   `msgs_to_messages`/`messages_to_msgs` converters; push `SharedIndex` fix
   upstream to `std/sem` instead of carrying it in `[effects] max`; retire local
   `ext_registry_gen` when upstream emits ABI 6.0.

Sequencing: (1) deletions → (2) splits + gate → (3)+(4) sum types + catalog
table → (5) lazy-load. Non-goals per ADR-002/NOTE-003: no file-count targets,
no WI-history deletion, no prose-quality CI, no big-bang Makefile rewrite.

Cheapest-first (overlaps PLAN-002 items 1+4 + §2 above): glossary source + gate
→ catalogue-row/loud-warning guard → runnable tour files with CI runs → options
record + surface check collapsing 9 `run_v2*` entries → 1.

## 6. Relation to open items

- PLAN-001: unchanged (DP7, batch semantics, FORK.md, preflight, provenance).
- PLAN-002: item 3 split targets confirmed against current line counts
  (session 3966, ports 2574, phase_vocab 1340); item 4 tour raw material now
  walked three times (NOTE-001, NOTE-008, this NOTE); §2's catalogue-row
  candidate is DONE as data, OPEN as guard.
- NOTE-008 finding 3 (`progress_contract_guard` vs assessment prose) reproduced
  twice this session: both guard pings that extended this demo were
  continue-with-feedback injections on report-shaped answers. Guard working as
  built; report-shaped tasks should end with an explicit completion claim.
- NOTE-008 finding 5 (`ReadFile` start-past-end papercut) not re-tested; still
  candidate for PLAN-002 item 5 triage.
