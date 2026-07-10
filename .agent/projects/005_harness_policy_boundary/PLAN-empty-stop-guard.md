# PLAN: empty-stop guard extension + core empty-stop-finalize safety floor

Implements **ADR-001** decisions **D1**, **D2**, **D3(b)** (this dir). Does **not** implement D4
(persist-nudge migration — separate `PLAN-persist-nudge-migration.md`) and does **not** touch
compaction.

Status: Proposed
Pinned toolchain: AILANG **v0.26.0** (`ailang.lock` → `ailang_version: "v0.26.0"`)
Grounded at: branch `arniwesth/mot-36-compactor-strategy-refinement`, HEAD **`b961ac6`**
(two commits past the ADR's `66a4ecb`: `7a8177c`, `b961ac6` — both compaction-only; the finalize
seam this plan touches is unchanged except a ~+5-line drift in `session.ail`, re-anchored below).

---

## TL;DR

Two deliverables, cleanly separable:

1. **Extension `empty_stop_guard`** (D1/D2): a new `motoko-ext-empty-stop-guard` package whose
   `on_solver_candidate` returns `ContinueWithFeedback(<task-agnostic message + marker>)` when the
   candidate is blank/whitespace **and** its history-counted budget is not spent, else `NoDecision`.
   No core mechanism change — the seam already loops on `ContinueWithFeedback`.

2. **Core floor `EmptyStopFinalize`** (D3(b)): one new `LedgerEvent`, emitted at the **true**
   finalize choke point — the `Finalize(info)` arm of `c2_loop` (`session.ail:1484`), **not**
   `c2_after_dp7` as the ADR states (see *ADR gaps*, gap A) — gated on blank finalize output. Fires
   with **zero** extensions loaded, so an empty stop is never a silent empty success.

The reactive behavior is entirely deliverable 1 (extension-side, opt-in per profile). The
never-silent invariant is entirely deliverable 2 (core, unconditional). They share no code and can
land in either order.

---

## Verified seam state at HEAD `b961ac6`

Every claim below re-verified at current HEAD (anchors drifted from the ADR; these are correct now):

- ABI unchanged: `on_solver_candidate: (ExtCtx, string) -> FinalizeDecision`
  (`packages/motoko-ext-abi/types.ail:159`); `FinalizeDecision = Accept | ContinueWithFeedback |
  NoDecision` (`types.ail:133`). `ExtCtx.history_slice: [Msg]` (`types.ail:89`).
- Dispatch + precedence: `dispatch_solver_candidate` → `merge_finalize_decisions` →
  `first_continue` gives `ContinueWithFeedback` > `Accept` > `NoDecision`
  (`src/core/ext/runtime.ail:314-326`). **Unchanged** since the ADR.
- The finalize match on the candidate: `dispatch_solver_candidate(rt, post_ctx,
  result.message.content)` at `session.ail:1805`, with the three arms `Accept` (1806),
  `ContinueWithFeedback` (1808 — emits `ExtSolverFeedback`, sets `last_finish_reason:
  "solver_feedback"`, loops), `NoDecision` (1833 — persist-nudge check, else `c2_after_dp7`).
- The candidate reaches this hook only on a stop path: `finish_reason != "tool_calls"`,
  `on_response_intercept` → `NoIntercept` (`session.ail:1713`), and hybrid bash extraction found
  nothing (`session.ail:1770-1804`). An **empty** response has no fence and nothing to intercept, so
  it reliably reaches the hook. **Confirmed — the ADR's §Context 3 still holds.**
- `post_ctx` (the `ExtCtx` handed to the hook) is built at `session.ail:1711` from
  `msgs_with_assistant = st.msgs ++ [assistant_msg]` (`session.ail:1710`); `history_slice =
  messages_to_msgs(msgs_with_assistant)` (`mk_v2_ext_ctx`, `session.ail:894`). `st.msgs` is the
  **full append-only history** — see OQ5 below.
- Finalize actually happens at the `Finalize(info)` arm in `c2_loop` (`session.ail:1484-1493`),
  which is the **sole** `DoneEvent` emission in the codebase (grep: `DoneEvent(` appears once in
  `src/core/`, at `session.ail:1487`) and the sole `emit_run_summary` on the success path.
  `c2_after_dp7` (`session.ail:1379`) does **not** end the run — it runs DP7 verification then
  re-enters `c2_loop` with `last_finish_reason: "dp7_approved"`, which `decide` maps to `Finalize`
  (`step_machine.ail:118-119`).
- `LedgerEvent` sum + JSON projection + golden bytes all live in
  `src/core/phase_vocab.ail`: sum at `592-624`, `to_schema_v1_kvs` at `664-698`, golden test
  `test_ledger_projection_golden_bytes` at `1084-1123`.
- Registry: extensions are declared in `ailang.toml [extensions].packages` (`ailang.toml:28-43`),
  code-genned into `src/core/ext/registry_generated.ail` (`resolve` name→`register_with_config`),
  and selected at runtime by a comma-separated **order string** (`cfg.extensions.order`, default
  empty — `src/core/config.ail:163`; env `CORE_EXT_ORDER`).

---

## Code-graph grounding

Cross-checked the structural claims against `ailang-graph` (`tools/code-graph/`, profile `core`,
built at HEAD `b961ac6`: 34 modules / 633 funcs / 870 invokes; `coverage ok=34/34`,
`stale=false`, `incomplete=false`). Call edges are **source-parsed approximations**
(`approximate=true`) — treated as corroboration, not compiler proof — but every load-bearing edge
below is exact and consistent with the direct reads above.

- **Finalize match lives in `c2_loop`.** `invokes` into `dispatch_solver_candidate` are exactly
  `session#c2_loop` (production) and `ext/runtime#dispatch_smoke_record_hooks` (a smoke helper).
  Precedence chain intact: `merge_finalize_decisions ← dispatch_solver_candidate` (sole caller) and
  `first_continue ← merge_finalize_decisions`.
- **Gap A corroborated structurally.** `c2_after_dp7`'s direct callees are exactly
  `{dp7_rejection_errors, count_persist_nudges, c2_loop}` — it **re-enters `c2_loop`** and does
  **not** reach any finalize emission. The success-path `emit_run_summary` is invoked only from
  `c2_fail` and `c2_loop`, so the run actually ends inside `c2_loop` (the `Finalize` arm), not in
  `c2_after_dp7`. (`DoneEvent` is a constructor, so it has no `invokes` rows — confirmed present once
  via grep at `session.ail:1487` and as a `ctors` row in `phase_vocab`; the `emit_run_summary` edge
  is the graph-side witness for the same arm.)
- **WI-4 / OQ4 dependencies reachable at the Finalize arm.** `catalog_context_limit_for` exists
  (`src/core/context_usage`) and is **already invoked by `c2_loop`** — the size fields need no new
  import. `mk_v2_ext_ctx` is invoked **only** by `c2_loop` (the `post_ctx` build site) and itself
  invokes `messages_to_msgs` — the exact `history_slice = messages_to_msgs(full history)` chain the
  OQ5 resolution rests on.
- **WI-3 sibling pattern + no collisions.** `ctors` shows `DoneEvent`, `ExtSolverFeedback`,
  `PersistNudge` all in `src/core/phase_vocab` (where `EmptyStopFinalize` will join them);
  `EmptyStopFinalize` is absent. No `empty_stop` / `EmptyStop` symbol exists anywhere in core
  (`funcs` query empty; `search empty_stop` → 0 rows) — all new names are collision-free.
- **Coverage caveat.** The `core` profile excludes `packages/**`, so the extension-side claims
  (WI-1/WI-2: the `register.ail` mirror, the `registry_generated` `resolve` arm, sibling ext hooks
  returning `NoDecision`) are grounded by direct reads above, not by this graph. Re-run
  `tools/code-graph/extract.sh --profile=all` if a reviewer wants those edges in-graph.

---

## Work items

Each WI names the file(s), the change, and the `make` gate that proves it.

### WI-1 — Extension package `motoko-ext-empty-stop-guard` (D1)

**New files** under `packages/motoko-ext-empty-stop-guard/`:
- `empty_stop_guard.ail` — pure guard logic (testable in isolation):
  - `is_blank(s) = trim(s) == ""` (use `std/string.trim`, already imported by
    `registry_generated.ail`) — covers empty **and** whitespace-only (OQ2 wording note below).
  - `guard_marker() -> string` — a single literal, e.g. `"[motoko-empty-stop-guard]"`, mirroring
    `persist_nudge_marker()` (`session.ail:1148`).
  - `guard_message() -> string` — **task-agnostic**, not WriteFile-specific. Draft:
    `"You returned an empty response but the task is not marked complete. Continue working on the
    task, or if you are genuinely finished, state your final answer or conclusion explicitly.
    [motoko-empty-stop-guard]"`. The marker is the **last** token so it is countable yet reads as a
    provenance tag.
  - `count_markers(history: [Msg]) -> int` — count `m.role == "user" && contains(m.content,
    guard_marker())`, structurally identical to `count_persist_nudges` (`session.ail:1214-1220`).
  - `decide(ctx, candidate) -> FinalizeDecision`:
    `if is_blank(candidate) && count_markers(ctx.history_slice) < budget() then
    ContinueWithFeedback(guard_message()) else NoDecision`.
  - `budget() -> int` — default **2** (OQ2). Read from config/env if the package follows the
    `test_dummy` env-config pattern (`EMPTY_STOP_GUARD_BUDGET`); a compile-time constant is
    acceptable for v1.
- `register.ail` — `register_with_config(_cfg: a) -> ExtensionHooks`, mirroring
  `motoko-ext-compaction-structural/register.ail` (all other hooks no-op: `on_pre_step`
  `PassThrough`, `on_tool_policy` `NoOpinion`, `on_tool_handle` `Delegate`, `on_response_intercept`
  `NoIntercept`, empty tools/prompt/budget). `id: "empty_stop_guard"`; `on_solver_candidate` wraps
  `empty_stop_guard.decide` in a `func(...) -> FinalizeDecision ! {IO, Process, FS, AI, Env, Net,
  SharedMem, Clock, Stream}` (the ABI hook carries the full effect row even though `decide` is pure —
  same as `compaction_structural`). Config-agnostic (`_cfg: a`) like `test_dummy`.
- **Naming convention (gotcha):** directory is hyphenated `motoko-ext-empty-stop-guard`, but the
  **module path and package id are underscored** — `module sunholo/motoko_ext_empty_stop_guard/register`
  / `.../empty_stop_guard`, package `sunholo/motoko_ext_empty_stop_guard@0.1.0`. The registry
  `resolve` name is the `motoko_ext_`-stripped basename → `empty_stop_guard` (matches the profile
  order token and `id`). Same split as every sibling (`motoko-ext-compaction-structural` ↔
  `sunholo/motoko_ext_compaction_structural`).
- `ailang.toml` / `motoko.pkg` package manifest matching a sibling ext package's shape.

**Gate:** `ailang check packages/motoko-ext-empty-stop-guard/register.ail` and the package's own
`ailang test packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail` (unit tests for `is_blank`,
`count_markers`, `decide` at/over budget).

### WI-2 — Register the extension (OQ3)

- Add `"sunholo/motoko_ext_empty_stop_guard@0.1.0"` to `ailang.toml [extensions].packages`
  (`ailang.toml:29-43`).
- Regenerate `src/core/ext/registry_generated.ail` via `ailang generate-extension-registry` (do
  **not** hand-edit — header line 1-3 forbids it). Confirm `resolve` gains the
  `"empty_stop_guard"` arm.
- **Profile inclusion (OQ3 resolution — floor always; guard opt-in-but-default-on):** the runtime
  default order is empty (`config.ail:163`), so "default profile" is per-config. Add
  `empty_stop_guard` to the `extensions.order` of the profiles that motivated this work — at minimum
  the qwen36 compaction-live config and any general agent profile — placing it **anywhere** in the
  order (finalize precedence is order-independent among finalize hooks unless a second finalize hook
  also returns `ContinueWithFeedback`; see Interaction below). Leave configs that deliberately run
  bare (DST/bench) without it — the D3(b) floor still protects them.

**Gate:** `make check_core` (type-checks all of `src/core/` incl. the regenerated registry) and
`make verify_extensions` (conformance).

### WI-3 — Core floor event `EmptyStopFinalize` (D3(b), OQ4)

In `src/core/phase_vocab.ail`:
- Add info type near `DoneInfo` (`phase_vocab.ail:531`):
  `export type EmptyStopFinalizeInfo = { step: int, input_tokens: int, estimated_input_tokens: int,
  context_limit: int }`. The three size fields resolve **OQ4** (self-diagnosing "ended because
  context was gutted"): `input_tokens`/`estimated_input_tokens` from `st.telemetry`
  (`last_input_tokens` / `last_estimated_input_tokens`), `context_limit` from
  `catalog_context_limit_for(model)` (already called at `session.ail:1554`). All cheap and present
  at the Finalize arm.
- Add constructor to the `LedgerEvent` sum (`phase_vocab.ail:592-624`):
  `| EmptyStopFinalize(EmptyStopFinalizeInfo)   -- [NEW] empty_stop_finalize`.
- Add the projection arm in `to_schema_v1_kvs` (`phase_vocab.ail:664-698`):
  `EmptyStopFinalize(i) => [kv("type", js("empty_stop_finalize")), kv("step",
  jnum(_int_to_float(i.step))), kv("input_tokens", jnum(_int_to_float(i.input_tokens))),
  kv("estimated_input_tokens", jnum(_int_to_float(i.estimated_input_tokens))), kv("context_limit",
  jnum(_int_to_float(i.context_limit)))]`.
- Add a golden line to `test_ledger_projection_golden_bytes` (`phase_vocab.ail:1084`):
  `&& golden(EmptyStopFinalize({ step: 96, input_tokens: 22312, estimated_input_tokens: 8600,
  context_limit: 131072 }), "{\"type\":\"empty_stop_finalize\",\"step\":96,\"input_tokens\":22312,\"estimated_input_tokens\":8600,\"context_limit\":131072}")`.

**Gate:** `ailang test src/core/phase_vocab.ail` (runs `test_ledger_projection_golden_bytes`).

### WI-4 — Emit the floor at the finalize choke point (D3(b))

In `src/core/session.ail`, the `Finalize(info)` arm (`1484-1493`):
- Before/after the existing `DoneEvent` emission (`1487`), add a gated emission:
  `if is_blank_output(info.output) then { let _ = ledger_emit(session_id,
  EmptyStopFinalize({ step: done_step, input_tokens: st.telemetry.last_input_tokens,
  estimated_input_tokens: st.telemetry.last_estimated_input_tokens, context_limit:
  catalog_context_limit_for(model) })); () } else ()`.
- Gate = **blank finalize output** only. "No tool calls" is already implied: `decide` returns
  `Finalize` **only** for `last_finish_reason ∈ {stop, dp7_approved, dp7_fail_open}`
  (`step_machine.ail:118-119`) — all non-tool-call stop paths. So `blank(info.output)` ⟺ the empty
  stop of the issue. (`is_blank_output` = `trim(info.output) == ""`; `trim` is **already imported**
  in `session.ail:35` — no new import.)
- **Do not** place this in `c2_after_dp7` (where the ADR points): an empty candidate that DP7
  *rejects* re-loops instead of finalizing, so an emit there would be a false positive. The
  `Finalize` arm is the one point every finalize route (Accept, NoDecision-no-nudge, dp7_fail_open,
  bare stop) converges on and actually ends. See *ADR gaps*, gap A.
- **Also append the event to the trace** (`ledger_append(trace_with_decision,
  WireRecord(EmptyStopFinalize(...)))` into the returned `trace`), mirroring how `ExtSolverFeedback`
  both emits and appends (`session.ail:1809-1810,1829`). The current `Finalize` arm emits `DoneEvent`
  to the ledger but does **not** append it to the trace, so without this the DST cannot observe the
  floor. This makes WI-6 assertions possible.

**Gate:** `make check_core`, then the DST in WI-6.

### WI-5 — (optional, recommended) flag `run_summary` on empty finalize

D3(b) permits "and/or flags `run_summary`". The `Finalize` arm calls `emit_run_summary(session_id,
model, st.totals, st.step_idx, 0, "", started_at_ms)` (`session.ail:1486`); the summary's
`finish_reason` is derived from the **`finish_code: int`** parameter (`emit_run_summary` sig
`session.ail:776-782`; `0 → "stop"` via `finish_reason_str`, `session.ail:764`), **not** a
finish-reason string. So an empty stop currently reports `finish_reason:"stop"`, indistinguishable in
the summary. Flagging it would mean either a new `finish_code` value mapping to `"empty_stop"` (and a
`finish_reason_str` arm + its own golden) or an added summary field — a wider change touching the
`run_summary` schema and its goldens. **Decision:** ship the distinct `EmptyStopFinalize` event
(WI-4) as the invariant (cheapest, self-contained, satisfies "never a silent empty success"); defer
the `run_summary` flag unless downstream log tooling needs to key off the summary alone — noted so a
reviewer can pull it forward without re-litigating.

### WI-6 — DST scenario (offline, deterministic)

Add scenarios to `scripts/phase_c2_wiring_scenarios.ail` (run by `make phase_c_l1` via
`ailang run ... scripts/phase_c2_wiring_scenarios.ail`), using the existing scripted-provider
harness (`run_scripted(rt, script)` / `Session.run_v2_session_traced*`, `stub_step.prose_step`).
`prose_step("")` yields `finish_reason:"stop"` with empty content — the exact trigger.

Build a `guard_rt()` helper mirroring `stub_step.deny_all_rt()` (which sets `verification.enabled =
false`, so DP7 auto-approves and the empty stop reaches `Finalize` — confirmed
`stub_step.ail:271-273`, `session.ail:1092`) but whose single hook's `on_solver_candidate` is the
real `empty_stop_guard.decide`. **Pin the budget explicitly to 2** in the helper (construct the hook
with an explicit-budget variant, or set `EMPTY_STOP_GUARD_BUDGET=2`) so the scenario stays
deterministic regardless of the shipped default. All scenarios use `run_scripted(rt, script)` (plain
runner, `persist_retries=0` — `phase_c2_wiring_scenarios.ail:162`), so the persist-nudge never fires
and the guard is the sole injector. Three assertions:

- **(a) guard injects + loops within budget.** `run_scripted(guard_rt(), [prose_step(""),
  prose_step("done")])` → decisions `["CallModel", "InjectUserMessage", "CallModel", "Finalize"]`
  (empty → `ContinueWithFeedback` → `solver_feedback` → `InjectUserMessage`; second step non-blank →
  `NoDecision` → finalize). Identical decision-name trace to the existing
  `scenario_traced_persist_nudge_decisions` (`phase_c2_wiring_scenarios.ail:190-215`), since both
  `solver_feedback` and `persist_nudge` map to `InjectUserMessage` in `decide`.
- **(b) budget exhaustion → NoDecision → floor fires.** `run_scripted(guard_rt(),
  [prose_step(""), prose_step(""), prose_step("")])` with budget 2 → two injections (marker lands as
  a `user` message in `st.msgs` before each next candidate check), then the third empty stop finds
  `count_markers == 2` (not `< 2`) → `NoDecision` → `Finalize` → `EmptyStopFinalize`. Decisions
  `["CallModel","InjectUserMessage","CallModel","InjectUserMessage","CallModel","Finalize"]`, **and**
  the trace contains an `EmptyStopFinalize` record.
- **(c) floor fires with NO guard loaded.** `run_scripted(empty_rt(), [prose_step("")])` → decisions
  `["CallModel", "Finalize"]` **and** trace contains `EmptyStopFinalize`. This is the
  zero-extensions safety-floor proof (default `persist_retries=0`, `NoDecision`, no nudge).

**Asserting the event (important — the generic name helper won't work).** `ledger_record_name`
(`phase_vocab.ail:558-575`) collapses every wire event except `ProviderCallPrepared` /
`ExtCompactionRejected` to the string `"wire"`, so an `EmptyStopFinalize` is **not** distinguishable
by name through it. The DST helper must pattern-match the constructor directly, e.g.
`has_empty_stop_finalize(trace) = any over trace.records of \r. match r { WireRecord(EmptyStopFinalize(_)) => true, _ => false }`.
(Alternatively add an `EmptyStopFinalize(_) => "empty_stop_finalize"` arm to `ledger_record_name` —
a trivial, reusable core one-liner — but the direct match keeps the change in the test file.) This is
also why WI-4 must **append** the event to the returned trace, not only `ledger_emit` it: the plain
`ledger_emit` writes to the IO ledger the DST does not read.

**Gate:** `make phase_c_l1`.

### WI-7 — full gate

`make check_core && make phase_c_l1 && ailang test src/core/phase_vocab.ail && make verify_extensions`
(and `make compaction_dst` unaffected but run to prove no regression). Bump `motoko-ext-abi`
consumers? **No** — the ABI is untouched (no `ExtensionHooks` change), so no abi major bump.

### Sequencing & dependencies

The two **deliverables** are independent and can land in either order (extension = WI-1/2/parts of
6; floor = WI-3/4). **Within** them the order is constrained:

- **WI-3 before WI-4.** `to_schema_v1_kvs` is an exhaustive match on `LedgerEvent` with no catch-all
  (`phase_vocab.ail:664`), so the `EmptyStopFinalize` constructor + its projection arm must exist
  before `session.ail` (WI-4) constructs it — otherwise neither module compiles.
- **WI-1 → WI-2 (`ailang.toml` + `ailang lock`) before WI-6.** The DST imports the guard module
  (`pkg/sunholo/motoko_ext_empty_stop_guard/empty_stop_guard`), which only resolves once the package
  is declared in `ailang.toml [extensions].packages` and hydrated into the lock. The registry
  regen and profile-order edits (rest of WI-2) are **not** prerequisites of the DST — it constructs
  `guard_rt()` directly, bypassing the profile order.
- **WI-6(b) needs WI-1 + WI-3 + WI-4** together (it asserts both the guard loop and the floor
  event); WI-6(c) needs only WI-3 + WI-4. So the full `make phase_c_l1` gate passes only after the
  floor and the guard both land, even though each could be developed against its own narrower gate
  first.

---

## Blast Radius

| File | Kind | Change |
|------|------|--------|
| `packages/motoko-ext-empty-stop-guard/empty_stop_guard.ail` | **extension (new)** | Pure guard logic: `is_blank`, `guard_marker`, `guard_message`, `count_markers`, `decide`, `budget`; unit tests. |
| `packages/motoko-ext-empty-stop-guard/register.ail` | **extension (new)** | `register_with_config` returning `ExtensionHooks` with only `on_solver_candidate` active; all other hooks no-op (mirror `compaction-structural`). |
| `packages/motoko-ext-empty-stop-guard/{ailang.toml,motoko.pkg,…}` | **extension (new)** | Package manifest matching a sibling ext package. |
| `ailang.toml` | metadata | Add `"sunholo/motoko_ext_empty_stop_guard@0.1.0"` to `[extensions].packages` (line 29-43). |
| `src/core/ext/registry_generated.ail` | **generated** | Regenerate via `ailang generate-extension-registry` (do not hand-edit) — gains the `"empty_stop_guard"` `resolve` arm. |
| `.motoko/config/<profile>/config.json` (real agent + qwen36 compaction-live profiles) | config | Add `empty_stop_guard` to `extensions.order`. Leave bare DST/bench configs unchanged. |
| `src/core/phase_vocab.ail` | **core** | New `EmptyStopFinalizeInfo` type + `EmptyStopFinalize` `LedgerEvent` constructor + `to_schema_v1_kvs` arm + one golden line. |
| `src/core/session.ail` | **core** | In the `Finalize(info)` arm (1484-1493): gated `EmptyStopFinalize` emission on blank output, and append it to the returned trace. No control-flow change. |
| `scripts/phase_c2_wiring_scenarios.ail` | test | `guard_rt()` helper + three scenarios (within-budget loop, budget-exhaustion floor, zero-extension floor) + an `assert_contains_event` helper. |
| `.agent/issues/silent-empty-stop-finalize.md` | docs | Flip status to resolved when landed. |
| `ailang.lock` | metadata | Refresh only if package content hashes change during implementation; do not churn for plan-only edits. |

**Expected not to touch:**
- `packages/motoko-ext-abi/types.ail` — **no ABI change**. The `on_solver_candidate` seam and
  `FinalizeDecision`/`ExtCtx.history_slice` already provide everything; no abi major bump, no
  consumer re-pin.
- `src/core/ext/runtime.ail` — `merge_finalize_decisions` / precedence unchanged; the guard is just
  another hook in the existing chain.
- `src/core/step_machine.ail` — `decide` unchanged. The floor gates on blank `info.output` at the
  `Finalize` arm; it adds **no** new decision variant and no `finish_reason` handling.
- `src/core/recovery.ail` and the in-core persist-nudge (`session.ail:1833-1861`) — untouched; their
  migration is **D4** / `PLAN-persist-nudge-migration.md`, explicitly out of scope here.
- Compaction: `src/core/compaction.ail` calibration and
  `packages/motoko-ext-compaction-{ai,structural}/**` — out of scope; this plan relies on the
  *existing* ephemeral behavior (`st.msgs` stays full/uncompacted), it does not modify it.
- Retained-history persistence — `st.msgs` remains the full append-only history (the property OQ5
  depends on).

---

## Resolutions of ADR open questions

- **OQ2 (false positives).** Budget default **2**; message is task-agnostic and explicitly invites a
  genuinely-finished model to *re-affirm completion in prose* — which is non-blank, so the next
  candidate hits `Accept`/`NoDecision` and finalizes normally. Worst case for a legitimately-empty
  final turn: 2 wasted steps + 2 short injected messages, then the floor marks it. Cost bounded and
  cheap. Blank test includes whitespace (`trim`) so a `" "`-only "answer" is treated as empty.
- **OQ3.** Floor (WI-3/4) is **unconditional core** — protects every profile. Guard (WI-1/2) ships
  in the `extensions.order` of the real agent/qwen profiles but is omitted from bare DST/bench
  configs. Resolved as the ADR leaned.
- **OQ4.** Event carries `input_tokens`, `estimated_input_tokens`, `context_limit` (WI-3) →
  "ended because context was gutted" is self-diagnosing from the single event.
- **OQ5 (budget durability).** **Resolved by verification, and it corrects the ADR's premise (gap
  B).** The counting source `ctx.history_slice` is built from `msgs_with_assistant = st.msgs ++
  [assistant]` (`session.ail:1710-1711,894`) — the **full append-only history**. Per-step
  compaction (structural **and** AI) only rewrites the ephemeral `compacted_msgs` provider payload
  (`session.ail:1648,1664`); it never mutates `st.msgs`. So the AI compactor *cannot* fold a marker
  out of the counting view — the ADR's central OQ5 worry does not occur. The guard's injected
  feedback becomes a real `user` message in `st.msgs` (via `solver_feedback` → `InjectUserMessage`,
  `session.ail:1494-1495`) and is counted on every later step. **Precedent:** `count_persist_nudges`
  counts over the full `msgs` the same way (`session.ail:1214,1422`). **Residual risk (real but
  tolerated):** *checkpointing* (`TakeCheckpoint` → `CheckpointTaken`) rewrites history to `pinned ++
  [summary]` (`phase_vocab.checkpoint`), which *can* drop old markers and reset the budget. This is
  identical to persist-nudge's exposure and is a *fail-safe-toward-more-continues* (each extra
  continue still costs a step, is bounded by `max_steps`, and the D3(b) floor catches the eventual
  empty finalize). Accept it for v1; if it bites, promote the count to a durable `ctx.artifacts`
  field (survives checkpoint) — noted, not built.

## Interaction correctness

- The guard runs inside the merged finalize chain. `merge_finalize_decisions` →
  `first_continue` returns the **first** `ContinueWithFeedback` in registry order
  (`ext/runtime.ail:298-326`); `ContinueWithFeedback` beats `Accept` beats `NoDecision`.
  **Verified across every shipped extension:** all 13 `motoko-ext-*` packages' `on_solver_candidate`
  return `NoDecision` today — plain (`compaction-{ai,structural}`, `scratchpad`, `omnigraph`,
  `microrag`, `decision-framework`, `a2a`, `mcp`, `ailang-docs`, `exa-search`, `compose`) or after a
  fire-and-forget side effect (`context-mode` `finalize_with_index` →
  `context_mode.ail:186 NoDecision`). So `empty_stop_guard` is the **only** finalize hook returning a
  non-`NoDecision`, and its `ContinueWithFeedback` wins regardless of order. ✔
- **Co-loading a second finalize guard** (the future persist-nudge migration, D4): if both return
  `ContinueWithFeedback` on the same candidate, `first_continue` picks the one **earlier in
  `extensions.order`**. Document in `PLAN-persist-nudge-migration.md` that on an empty candidate the
  empty-stop guard should win (it is the more general condition); order it before persist-nudge, or
  have the coding guard early-return `NoDecision` on blank input (blank ⟹ empty-stop's concern, not
  lazy-prose). This plan only requires empty-stop guard to be present; no ordering constraint exists
  until the second guard lands.

---

## ADR gaps found

The ADR was *mostly* sufficient — D1/D2/D3(b) and OQ2–OQ5 map onto concrete work items — but two
source claims in it are imprecise against the code at HEAD and would have produced wrong placement
if followed literally. Both are resolvable (this plan resolves them); reporting per the handoff's
freshness test.

- **Gap A — the finalize choke point is misidentified.** ADR §Context 3 (and D3(b)) says both
  finalize routes "converge on `c2_after_dp7(...)` … the single choke point where the run actually
  ends," and directs the D3(b) emission there. Verified false: `c2_after_dp7` (`session.ail:1379`)
  runs DP7 verification and **re-enters `c2_loop`**; the run actually ends at the `Finalize(info)`
  arm (`session.ail:1484`), the sole `DoneEvent`/`run_summary` site. Emitting at `c2_after_dp7`
  would misfire when an empty candidate is DP7-**rejected** (it loops, doesn't finalize). This plan
  emits at the `Finalize` arm instead (WI-4). Impact: placement corrected; decision D3(b) itself
  stands.
- **Gap B — OQ5's compaction premise doesn't match the code.** OQ5 frames the durability risk as
  "the AI compactor summarizes old user/assistant turns … could fold a marker into a summary … the
  guard must count on a view that retains them (full history, **not** a compacted
  `ctx.history_slice`)." But `ctx.history_slice` **is** the full history (`session.ail:894,1710`);
  compaction never touches `st.msgs`. So counting in `ctx.history_slice` is already correct and
  durable against per-step AI compaction — the extra machinery OQ5 contemplates (a summarizer-
  preserved marker phrase, a durable `ctx` field) is unnecessary for that threat. The genuine
  residual is *checkpointing*, which OQ5 does not name. Impact: OQ5 resolved more simply than the
  ADR anticipated, with the real risk correctly identified.
- **Gap C (minor).** The empty stop finalizes via `last_finish_reason == "dp7_approved"` (routed
  through `c2_after_dp7` with no verifier), not the literal `"stop"` branch — both map to `Finalize`
  in `decide` (`step_machine.ail:118-119`). Immaterial to the plan because WI-4 gates on blank
  `info.output` at the `Finalize` arm (finish-reason-agnostic), but noted so no one keys the floor
  on `finish_reason == "stop"`.

Everything else (D1/D2, the ABI seam, precedence, budget-as-transcript-state, registration flow, the
DST harness) was directly plannable from ADR-001 + the code without guessing.
