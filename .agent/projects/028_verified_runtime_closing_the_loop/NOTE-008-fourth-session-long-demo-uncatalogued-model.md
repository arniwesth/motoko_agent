# NOTE-008 — fourth live session: long demo + assessment under an uncatalogued model (2026-09-03)

Date: 2026-09-03. Model: `openrouter/meta/muse-spark-1.3`. Profile: `default`
(`max_steps: 300`, 9 extensions active). Task: none — a long read-only demo/tour
of the runtime plus an assessment, ~70 executed steps. No files modified, so no
`check_core` gate was owed; targeted `ailang check` runs below are the evidence.

## Session facts (measured, from `MotokoRuntimeStatus`)

- `step_budget: 300` throughout; `steps_executed_so_far` 4 → 70 over the session.
- `system_prefix`: stable, `count 1`, `chars 11189`,
  `digest sha256:28fc500c…` — unchanged across every sample.
- `context_limit: 0` on every sample (model uncatalogued; see finding 1).
- `compaction.{stage_applied_total, stage_rejected_total, compaction_ai_applied}`:
  all 0 at close. No compaction occurred.
- Token growth (cumulative): ~1.2M in / 29k out at step 25; ~8.2M in / 87k out
  at step 66; `last_sent.input_tokens` ~230k at close. ~96% of input is
  `cache_read_input_tokens` — cache attribution is working and honest.

## What was verified live

| Item | Result |
|---|---|
| `ailang run --entry print_version --caps IO src/core/version.ail` | `0.2.0` |
| `ailang run --entry main --caps IO src/examples/hello_world/hello_world.ail` | `Hello world!` |
| `ailang check src/core/tool_catalog.ail` | clean (only VER001 lock-skew warning, v0.33.0 lock vs v0.33.1 binary) |
| `ailang check src/core/rpc.ail src/core/session.ail src/core/step_machine.ail` | clean |
| `ailang check cost_phase / recovery / parse / tool_contract / fs_node` | clean |
| Architecture tour (read-only) | `supervisor → rpc` (thin launcher, M10b) → `session.ail` (3707-line live driver) + `agent_loop_v2` facade; 7 native tools; 22 extension packages present, 9 active; `step_machine` pure decide; `model/tool/hook` phases; `ports` (2574 lines); `ext_world` opaque-token codec; `fs_node` kind vocabulary; structural + AI compaction; DST suite (`event_vocabulary → fault_catalogue → generator → discovery → replay → persistence → secrets → run_report → invariants → execution bridge`); TUI protocol (`session_start … run_summary`), env-server `/exec` + `/health`, model-routing strip rules |

## Findings

### 1. NOTE-005 finding 1 still reproduces on the default profile
A missing model-catalogue row resolves the context limit to 0, and every
consumer reads 0 as healthy: `usage_pct: 0` while `last_sent.input_tokens`
was ~230k real tokens. Compaction was therefore blind for the entire session
— not broken, never switched on. The taskless third session found this;
a fourth session with a different uncatalogued model confirms it is the
steady state, not a one-off. Cheapest fix remains what NOTE-005 implies:
a catalogue row for whatever model the default profile actually pins
(`openrouter/meta/muse-spark-1.3` today), or a loud startup warning when the
limit resolves to 0 on a profile that installs compaction.

### 2. Cost of a read-heavy tour, measured
~8.2M cumulative input tokens for ~70 read steps (~117k/step, ~96% cache
reads). The affine-calibration design (`density 1235 permille` + ~19k fixed
overhead) is load-bearing at exactly this scale: a pure-ratio calibrator
anchored on a compacted window would over-estimate large windows ~2x and feed
a compaction loop. No new defect — but a number future tour tasks should
budget against.

### 3. `progress_contract_guard` fires on assessment-shaped answers
Ending the assessment with "here is what remains / what to run next" language
drew a `ContinueWithFeedback` injection (budget 2, marker
`[motoko-progress-contract-guard]`). The guard's contract check
(`do not stop early / continue until / current_step / below the target`) plus
self-report check (`continuing / remaining / step N/M`) is working as built;
the lesson for report-shaped tasks is to end with an explicit completion claim
and no continuation phrasing, or the guard correctly refuses the stop.

### 4. Interactive `make run` does not fit the tool ceiling
`./scripts/install-prerequisites.sh` + `make run` timed out at 35s with no
output — it installs toolchains then launches an interactive TUI that waits
for input. Same shape as NOTE-005's delegation finding: some surfaces are
unreachable inside one tool call. Long-demo tasks should use
`MOTOKO_HEADLESS=1 TASK=… ./scripts/run-agent.sh` or the bounded targets
(`smoke_parity`, `check_core`, DST scripts), never interactive `make run`.

### 5. Minor UX sharp edge (operator error, recorded honestly)
`ReadFile` with `start` past the default `end` (200) returns a single line
with `truncated: true` and no error, rather than refusing the range. My error
(`start: 640`, no `end`), but a one-line `invalid range` error would have been
cheaper than three re-reads. Not a defect class — a papercut candidate for
failure-mode triage (PLAN-002 item 5).

### 6. No new core-loop defects
Every `ailang check` run was green; the dispatch/policy/compaction code read
this session matches its own headers' claims (holder stamp WI-D24, S12
identity transitions on noop ports, `exit_code: -1` on no-op tool handles,
`Pending` deliberately unused by `repetition_guard`). The guards file
(`empty_stop` pushes continue, `progress_contract` pushes continue,
`repetition` argues stop via `ToolPolicy.Deny` + `SolverJudge.Accept`) is
coherent after NOTE-007 — the asymmetry it documents is now closed on the
tool-calling half.

### 7. Complexity: making Motoko model-legible (operator question, answered in-session)
Asked how to deal with the complexity most models point out (NOTE-003's
measurements: 48 WI ids / 861 mentions, `phase_vocab` 52 types fan-in 13,
`session.ail` ~3.7k lines, Makefile ~2.7k lines / 103 targets). Two tracks:

Track A — model-legible now, no code churn: (1) one `MOTOKO-MAP.md` entry
point (L1 loop diagram, L2 module map with what-NOT-to-read, L3
symbol-anchored deep links, never line numbers) — this tour cost ~8.2M input
tokens by breadth-first reading; a map turns it into lookup; (2) generate the
PLAN-002 item-1 glossary (WI/M/D/ADR ids → one line + doc link, plus
machine-readable JSON for context_mode/microrag retrieval) with
`glossary_check`; (3) runnable tour as the doc set (PLAN-002 item 4 — five
CI-run files; this NOTE + NOTE-001 are the twice-walked raw material);
(4) subsystem prompt cards loaded on demand (the `decision_framework`
conditional-patch pattern applied to DST/compaction/herdr); (5) fix the
model-visible lies first — finding 1 above (limit 0 reads as healthy).

Track B — lower it structurally (PLAN-002 order): options record + surface
check collapsing 9 `run_v2*` entries → 1; split hubs along named seams
(`phase_vocab` → events/state/policy; `session.ail` → loop/DP7/fixtures;
`stub_step` out of the prod import graph); symbol-anchored references (item 6);
shared refusal shape `{code, reason, retry_hint}` (item 5, co-designed with
026 §3.1). Non-goals per ADR-002: no file-count targets, no WI-history
deletion, no prose-quality CI, no big-bang Makefile rewrite.

Cheapest-first sequencing proposed: glossary source + gate (half a day) →
catalogue row/warning for the pinned default model → tour files with CI runs →
options record + surface check.

## Assessment (condensed; agrees with NOTE-001's 9/7/6)

Concept proven (typed tool-use loop, fail-closed registry, two-sided DST
grading, honest telemetry). Execution solid but expensive: the comprehension
tax (56 core modules, 3.7k-line driver, ten DST layers) and the fail-open
context-limit default are the two structural costs. Usability hinges on
bounded entry points — headless, smoke, DST scripts — not the interactive TUI.

## Relation to open items

- PLAN-001: unchanged; DP7/batch/doc-drift/preflight/provenance all still open.
- PLAN-002 item 4 (runnable tour): this NOTE plus NOTE-001 §"What was verified"
  are raw material — the tour path is now walked twice.
- New candidate item: catalogue row (or loud warning) for the default profile's
  pinned model — finding 1 above. Without it, every long session on the
  default profile runs with compaction silently off.
- Finding 7 proposes cheapest-first model-legibility sequencing (glossary →
  catalogue row → tour files → options record); overlaps PLAN-002 items 1+4
  and the catalogue candidate above — fold together when scheduling.
