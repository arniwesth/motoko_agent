# Handoff: implement the empty-stop guard + core empty-stop-finalize floor

Date: 2026-07-10 (written after `PLAN-empty-stop-guard.md` was reviewed against code until no major
issues remained; the review corroborated the finalize seam with `tools/code-graph`).
Audience: a fresh implementer session. **The plan is the spec**: `PLAN-empty-stop-guard.md` in this
directory. This handoff carries only the residual context that is easy to lose: current state,
reading order, guardrails, and the traps already found during review.

## Why this work exists

A live Qwen run finalized silently on an empty model response (`finish_reason:"stop"`, blank content,
no tool calls) and the harness reported it as a clean, empty success. Two fixes, per **ADR-001**:
1. **D1/D2** — a new `empty_stop_guard` extension that reacts to a blank finalize candidate by
   injecting a task-agnostic continue message, bounded by a history-counted budget.
2. **D3(b)** — a core safety floor: a distinct `EmptyStopFinalize` ledger event so an empty stop is
   never a silent success **even with zero extensions loaded**.

This is **not** the persist-nudge migration (D4, separate plan) and does **not** touch compaction.

## Current state

- Branch: `arniwesth/mot-36-compactor-strategy-refinement`.
- HEAD when this handoff was written: **`b961ac6`** (`Add compaction control capsule`).
- Committed and normative: `ADR-001-harness-policy-boundary.md`, `PLAN-empty-stop-guard.md` (this
  dir), `../../issues/silent-empty-stop-finalize.md`.
- The seam anchors in the plan were re-verified at `b961ac6`; `session.ail` drifted ~+5 lines from
  the ADR's `66a4ecb`. **Re-grep every symbol at your HEAD before trusting a line number** — assume
  they have moved again.
- `ailang.lock` is modified in the worktree from prior work. Do not treat it as part of this change
  unless you add a package (you will — see WI-2) and intentionally refresh it.
- A code-graph exists at `tools/code-graph/.out/` (profile `core`). Refresh with
  `tools/code-graph/extract.sh` if you want to re-confirm call edges; it excludes `packages/**`.

## Reading order

1. `PLAN-empty-stop-guard.md` — **the spec.** Read TL;DR, "Verified seam state", the WI-1…WI-7 work
   items, "Sequencing & dependencies", and "ADR gaps found" before opening code.
2. `ADR-001-harness-policy-boundary.md` — decisions D1/D2/D3(b) and OQ2–OQ5 (the plan resolves each).
3. `../../issues/silent-empty-stop-finalize.md` — the failure and the guard-as-extension shape.
4. Current code, re-grepping at your HEAD:
   - `src/core/session.ail` — the `Finalize(info)` arm (WI-4 target) and the
     `dispatch_solver_candidate` match (the seam).
   - `src/core/phase_vocab.ail` — `LedgerEvent` sum, `to_schema_v1_kvs`,
     `test_ledger_projection_golden_bytes`, `ledger_record_name` (WI-3 + the DST assertion trap).
   - `packages/motoko-ext-compaction-structural/register.ail` and
     `packages/motoko-ext-test-dummy/register.ail` — the two shapes to mirror for the new package.
   - `scripts/phase_c2_wiring_scenarios.ail` + `src/core/test/stub_step.ail` — the DST harness
     (`run_scripted`, `prose_step`, `empty_rt`/`deny_all_rt`).

## Scope guardrails

- Extension work is **extension-side only** (`packages/motoko-ext-empty-stop-guard/**` + registry +
  profile config). The floor is **one event** in `phase_vocab.ail` + **one gated emission** in the
  `Finalize` arm of `session.ail`. Nothing else in core changes.
- **No ABI change.** `packages/motoko-ext-abi/types.ail` is untouched — the `on_solver_candidate`
  seam already exists; no abi major bump, no consumer re-pin.
- Do **not** touch `step_machine.ail` `decide`, `ext/runtime.ail` precedence, `recovery.ail` /
  the in-core persist-nudge (that is D4), or any compaction module.
- Do **not** mutate the append-only `st.msgs` model — the budget-counting correctness (OQ5) depends
  on `ctx.history_slice` being the full history.

## Traps ranked by cost (found during plan review — do not rediscover them)

1. **Emit the floor at the `Finalize` arm, NOT at `c2_after_dp7`.** The ADR says the run "converges
   on `c2_after_dp7`"; it does not — `c2_after_dp7` runs DP7 verification and **re-enters `c2_loop`**.
   The only place the run actually ends (and the sole `DoneEvent` site) is the `Finalize(info)` arm.
   Emitting at `c2_after_dp7` would misfire when an empty candidate is DP7-**rejected** (it loops).
   (Graph-confirmed: `c2_after_dp7`'s callees are `{dp7_rejection_errors, count_persist_nudges,
   c2_loop}` — no finalize emission.) This is "ADR gap A" in the plan.

2. **The DST cannot assert the event by name — `ledger_record_name` returns `"wire"`.** It only
   names `ProviderCallPrepared` / `ExtCompactionRejected`; everything else collapses to `"wire"`. Your
   DST helper must pattern-match `WireRecord(EmptyStopFinalize(_))` **directly** (or add an arm to
   `ledger_record_name`). This is also why WI-4 must **append the event to the returned trace**, not
   only `ledger_emit` it — the DST reads the trace, not the IO ledger.

3. **WI-3 must land before WI-4 or nothing compiles.** `to_schema_v1_kvs` is an exhaustive `match`
   on `LedgerEvent` with no catch-all. Add the `EmptyStopFinalize` constructor **and** its projection
   arm together, before `session.ail` constructs the event.

4. **Gate the floor on `info.output`, not the candidate.** `Finalize` only fires for
   `last_finish_reason ∈ {stop, dp7_approved, dp7_fail_open}` (all non-tool-call stop paths), so
   `trim(info.output) == ""` ⟺ empty stop. Gating on `info.output` (not the raw candidate) is
   deliberate: an extension that `Accept`s with substantive output must **not** trip the floor.
   `trim` is already imported at `session.ail:35` — no new import.

5. **Naming split: hyphen dir, underscore module.** Directory `motoko-ext-empty-stop-guard`; module
   `sunholo/motoko_ext_empty_stop_guard/…`; package `sunholo/motoko_ext_empty_stop_guard@0.1.0`;
   registry `resolve` name and profile-order token and `id` all = `empty_stop_guard`. Copy the split
   from any sibling exactly.

6. **Count the budget over `ctx.history_slice`, matching persist-nudge.** `ctx.history_slice` is the
   **full append-only history** (built from `st.msgs ++ [assistant]`), not a compacted view — per-step
   compaction never touches `st.msgs`. Count `role=="user" && contains(content, guard_marker())`,
   cap at `budget()`. Mirror `count_persist_nudges`. The injected feedback becomes a `user` message,
   so the marker must be part of `guard_message()`.

7. **The DST budget must be pinned, not env-dependent.** Build `guard_rt()` so the guard uses budget
   **2** deterministically (explicit-budget hook variant, or `EMPTY_STOP_GUARD_BUDGET=2`), else the
   3-empty-step scenario is non-deterministic. `deny_all_rt` sets `verification.enabled=false`, so DP7
   auto-approves and the empty stop reaches `Finalize` — reuse that property.

8. **The guard hook carries the full effect row even though `decide` is pure.** Wrap `decide` in
   `func(...) -> FinalizeDecision ! {IO, Process, FS, AI, Env, Net, SharedMem, Clock, Stream}`, same
   as `compaction_structural`'s no-op hooks.

## Suggested implementation order

Floor first (self-contained, unblocks the DST's zero-extension proof), then the guard:

1. **WI-3** — add `EmptyStopFinalizeInfo`, the `EmptyStopFinalize` constructor, the `to_schema_v1_kvs`
   arm, and one golden line. Gate: `ailang test src/core/phase_vocab.ail`.
2. **WI-4** — gated emission + trace-append in the `Finalize` arm. Gate: `make check_core`.
3. **WI-1** — the `motoko-ext-empty-stop-guard` package (`empty_stop_guard.ail` + `register.ail` +
   manifest) with unit tests. Gate: `ailang check` + package `ailang test`.
4. **WI-2** — declare in `ailang.toml`, `ailang generate-extension-registry`, `ailang lock`, add
   `empty_stop_guard` to the real profiles' `extensions.order`. Gate: `make check_core` +
   `make verify_extensions`.
5. **WI-6** — three DST scenarios (within-budget loop, budget-exhaustion→floor, zero-extension→floor)
   + the direct-match event helper, in `scripts/phase_c2_wiring_scenarios.ail`. Gate: `make phase_c_l1`.
6. **WI-5** is explicitly deferred — do **not** flag `run_summary` unless a reviewer asks; the event
   is the invariant.

## Verification

Required before commit (WI-7 full gate):

```bash
make check_core
ailang test src/core/phase_vocab.ail
make phase_c_l1
make verify_extensions
make compaction_dst   # unaffected; run to prove no regression
```

Expected outcomes:
- Golden bytes for `empty_stop_finalize` match exactly (integers render without `.0`, kv order =
  type, step, input_tokens, estimated_input_tokens, context_limit).
- DST (a): guard loops within budget → `["CallModel","InjectUserMessage","CallModel","Finalize"]`.
- DST (b): budget exhausts → `NoDecision` → `Finalize` → trace contains `EmptyStopFinalize`.
- DST (c): **no guard loaded** → `["CallModel","Finalize"]` → trace contains `EmptyStopFinalize`.
- `make verify_extensions` boots `empty_stop_guard` cleanly in the profiles you added it to.

## Commit and closeout

- Reasonable to split into two commits (core floor; extension + DST) or keep as one focused change.
- Flip `../../issues/silent-empty-stop-finalize.md` status to resolved when landed.
- If implementation diverges from the plan, add
  `NOTE-empty-stop-guard-implementation-findings.md` in this directory and link it from here.
- The follow-on `PLAN-persist-nudge-migration.md` (D4) is separate — do not start it.

## Pre-flight

```bash
git rev-parse --short HEAD
git status --short
git log --oneline -12 -- src/core/session.ail src/core/phase_vocab.ail scripts/phase_c2_wiring_scenarios.ail packages/
grep -n "Finalize(info)\|dispatch_solver_candidate\|c2_after_dp7" src/core/session.ail   # re-anchor
make check_core && make phase_c_l1
```
