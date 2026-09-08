# Handoff: implement the re-derivation & context strategy

Date: 2026-07-11 (written by the session that authored `PLAN-rederivation-context-strategy.md`, grounded
it against pi/little-coder source + the Motoko code, and hardened it through a two-pass review that found
the WS1/WS2 correctness trap).
Audience: a fresh implementer session. **The plan is the spec**: `PLAN-rederivation-context-strategy.md`
in this directory. This handoff carries only the residual: current state, the discipline, and the traps
ranked by cost. Do **not** re-derive the design from the issue or re-survey the other harnesses — the plan
already compressed all of that (its §Prior-art table has the external `file:line` anchors if you need them).

## Why this work exists (one paragraph)

After the strategy fixes landed (sibling plan, already implemented), compaction *works* every step but the
run's cost is dominated by **re-deriving an ever-growing summary from scratch, every step** — a live
qwen36 run billed **4.2M input tokens** for 20K output, almost all of it re-summarizing history that is
discarded each step (ephemeral by design: `session.ail:1660` send-only payload; `:1722`
`msgs_with_assistant = st.msgs ++ [assistant_msg]` keeps the full history). The reference small-model
harness pi/little-coder (same target model, Qwen3.6-35B-A3B) avoids this because compaction is a **rare,
persistent, incremental** event. This plan ports that cost profile **into the ephemeral model** (audit
log untouched). Normative issue: `../../issues/compaction-rederive-cost-dominates-after-strategy-fixes.md`.
This is PLAN-level refinement of an extension-resident strategy (`004/ADR-001` D9), **not** an ADR — see
the plan's §Governance.

## Current state (verify, don't trust)

- Branch: `arniwesth/mot-38-progress-contract-finalize-guard-extension`. HEAD: **`af615cb`**.
- **Prerequisite already satisfied.** The sibling `PLAN-compactor-strategy.md` is **implemented**
  (`7a8177c`): `compaction_structural.ail` has result-based tiering (`result_target_pct:30`, base-check
  `:155`) and `compaction_ai.ail` has the batch/no-op guard. **It shipped with different symbol names than
  that plan proposed** (e.g. `calibrated_ctx_usage(...) < result_target_pct()`, not `select_by_result`).
  So: start directly on WS1+WS2; but re-grep any sibling-plan symbol before you build on it.
- **The summarizer-hang/degrade fix is landed** (`550b8bb`): `compaction_ai.ail` now has
  `summarize_attempt` / `summarize_with_ai_result` / `finalize_compaction` and degrades to `PassThrough`
  on summarizer failure. WS2 builds on top of `finalize_compaction` (`:351`).
- **Commit the plan first.** `git status` shows `PLAN-rederivation-context-strategy.md` with uncommitted
  review edits. Commit it (docs-only) before touching source, so your implementation diff is clean. (The
  modified `.motoko/config/*`, `Makefile`, `ailang.lock` in the tree are pre-existing, unrelated — leave
  them.)
- Key anchors re-verified at `af615cb`: `compaction_ai.ail` `compact_with_ai:359`, threshold gate `:361`,
  `cached_summary:315`, `split_msgs:206`, `finalize_compaction:351`; `session.ail` pre-step ctx `:1640`,
  `chain.artifacts` write-back `:1689`, ephemeral wiring `:1722`; chain fold `runtime.ail:152`; structural
  elision `compaction_structural.ail:85-100`. **They drift the moment you edit — re-grep.**

## Reading order

1. `PLAN-rederivation-context-strategy.md` — **the spec.** Read in this order: **§Governance** (what you
   need to proceed: nothing but the already-landed sibling plan), then **§Pre-step chain composition
   (ground truth)** — this is the load-bearing mental model; the whole WS1/WS2 design turns on it — then
   the workstream you're building.
2. `../../issues/compaction-rederive-cost-dominates-after-strategy-fixes.md` — the acceptance criteria
   (its Recommended-direction list). Its Prior-art section has the pi/little-coder mechanics if you want
   the source.
3. `../../issues/compaction-summarizer-hang-and-degrade.md` — WS2 directly shrinks this hang surface;
   read so you understand what "fewer, smaller AI folds" buys.
4. `ADR-001-compaction-persistence.md` — **only** to understand what you are *not* doing. Persistence is
   the fork this plan defers; do not drift toward mutating `st.msgs`.

## Non-negotiable discipline

- **Stay inside the ephemeral guardrails (plan §Scope + §Governance).** Do **not** mutate `st.msgs`
  (`session.ail:1722`), do **not** touch `src/core/compaction.ail` calibration. WS1/WS2/WS3(FS)/WS4a are
  **all extension-only** — a diff that touches `st.msgs ++ [assistant_msg]` or `affine_calibrate`, or that
  edits `packages/motoko-ext-abi/` or `src/core/tool_phase.ail`, is wrong by construction (those belong to
  the *optional* WS4b/ABI path, which is gated behind measurement and its own ABI note — not this work).
- **Gates green before every commit:** `make compaction_dst` and `make conformance`. Add your new
  scenarios to `scripts/long_qwen_compaction_dst.ail`. For the AI-extension slice, also
  `AILANG_RELAX_MODULES=1 ailang test packages/motoko-ext-compaction-ai/compaction_ai.ail` and
  `MOTOKO_CONFIG=hunyuan3-free-compaction-live make verify_extensions`. (Repo `npm test` / jest-under-bun
  is broken repo-wide — do not gate on it.)
- **Every source claim you add** (commit messages, new comments) carries a `file:line` you verified at
  your working HEAD. Encode *which invariant each change preserves* — the review found the sharp edges the
  hard way.

## The traps, in order of expense

Ranked so you read them *before* a red gate, not after. Each is fully specified in the plan; this is the
index.

1. **(WS1 — THE trap) Never `PassThrough` to raw history once over threshold — plan §Pre-step chain
   composition + §WS1.** `compaction_structural` runs *after* `compaction_ai` and elides only
   `role=="tool"` content (`elide_walk:89`) — **old user/assistant/thinking turns pass through untouched**
   (`:100`). So a `PassThrough` from the AI compactor does **not** bound a long run; prose accumulates
   until overflow. The AI summary is the *only* thing that collapses old prose, and ephemeral discards it
   each step → the compactor must **emit a bounded `Compacted(prefix + summary + tail)` every over-threshold
   step**. The trigger (WS1) gates the AI *call* (refresh vs. reuse cache), not compaction. **WS1 has no
   standalone value — build it together with WS2.**
2. **(WS2) Contiguous tail from the boundary — plan §WS1 Change.** `tail = turns after boundary_marker`
   (recomputed each step), **not** a fixed-size window with separate eviction. A fixed tail drops the turns
   between the summary boundary and the evicted tail edge (they're in neither summary nor tail) → silent
   context loss on reuse steps. Refresh (AI fold) fires exactly when the contiguous tail exceeds the token
   budget (~20k); that fold advances `boundary_marker` and shrinks the tail. Mirrors pi's `findCutPoint`.
3. **(WS2) The cache round-trips via `artifacts` — verified, keep it intact.** `compact_with_ai` returns
   `Compacted(msgs, note, artifacts)`; `fold_pre_step_chain_rec` threads it (`runtime.ail:172`) and
   `session.ail` writes `chain.artifacts` into next-step `ext_artifacts` (`:1689` et al.). If you forget to
   return the *updated* artifacts on a fold, the cache is silently lost and you re-derive every step — back
   to the pathology with no error. Extend `cache_artifact`/`cached_summary` (`:315`); don't bypass them.
4. **(WS2) `boundary_marker` must be stable across the growing history.** Reference a turn by a stable
   id/content-hash or absolute index into the append-only `st.msgs`, not a relative offset that shifts as
   turns append. Engine B's chunk digests are content-addressed for the same reason.
5. **(WS2) The tail cut must not sever a tool_call from its result.** `split_msgs:206` already respects
   this; preserve it when you convert `keep_recent` from a message count to a token budget. A `Compacted`
   payload that severs a pair is rejected by `validate_compactor_output`, and **a rejected stage silently
   disables compaction for that step** (`runtime.ail:175-177`) — worse than a crash, because the run keeps
   going with an unbounded window.
6. **(WS2) Engine A first; *measure* drift before building B — plan §WS2.** Ship Engine A (rolling fold,
   pi-validated). Run a ≥several-hundred-step session and check whether the summary decays (old facts
   dropped/garbled). Only build Engine B (frozen chunks) if decay shows. A and B are **co-primaries** (A
   for interactive length, B for the 1000-step target), **not** primary/fallback — but don't build B
   speculatively.
7. **(WS4a) Use Motoko's own token estimate — plan §WS4.** Cap oversized single tool-results in
   `compaction_structural.compact_for_pre_step` with Motoko's char/4 / `calibrated_usage_percent_with_limit`
   against `ctx.context_limit` — **not** little-coder's `chars/3.5`. And you're editing `compact_for_pre_step`
   which the sibling plan *also* rewrote — read its current shape first; add a per-message size cap inside
   the existing tier logic, don't fight it.
8. **(WS3) The evidence store is FS-backed — plan §WS3.** The `artifacts` channel is **write-only from
   `on_pre_step`**; `on_tool_handle` (where a model-controlled `EvidenceAdd` tool runs) cannot write it. So
   the store is a file (via the `FS` effect `on_tool_handle` has), read back in `on_pre_step`; re-surface a
   **pointer** (count + "via EvidenceList/EvidenceGet"), not the payload. The in-band artifacts-backed
   version needs ABI addition #2 — out of scope here.

## Suggested WI breakdown and order (from plan §Sequencing)

1. **WI-1 (WS1+WS2 Engine A — the core, one change):** in `compaction_ai.ail`, make `compact_with_ai`
   emit `Compacted(prefix + cached_summary + contiguous_tail)` on every over-threshold step; refresh via a
   delta-only fold (update-prompt over turns past `boundary_marker`) only when the tail overflows the token
   budget; cache `{summary, boundary_marker}` in `artifacts` via `cache_artifact`. Add the structured
   summary schema + cumulative file-op line. New tests: **AI-fold cadence** drops from every-step, and
   **every over-threshold step emits a bounded `Compacted`** (never raw history). Gates green.
2. **WI-2 (measure):** long-run drift check on Engine A → decide whether the long-horizon path needs
   Engine B. Record the finding (NOTE) regardless.
3. **WI-3a (WS4a, extension):** per-message oversized-tool-result cap inside `compact_for_pre_step`
   (Motoko estimator), reusing `elide_content`. New unit test: big read at high usage trimmed, small read
   untouched.
4. **WI-3b (WS3, extension):** FS-backed evidence store (`EvidenceAdd/Get/List`) + post-fold pointer
   bridge; `_smoke.ail`. Independent of WI-1/WI-3a; can run in parallel.
5. **WI-4 (optional, gated):** Engine B if WI-2 showed drift; ABI notes (#1 WS4b, #2 in-band WS3) only if
   the residual justifies them. **Do not** open these without their own note under `004/ADR-001` D9.

Each WI: both gates green before committing.

## Definition of done

- Both gates green: `make compaction_dst`, `make conformance`; plus the AI-slice `ailang test` and
  `verify_extensions` for the hunyuan profile.
- New tests exist and pass (plan §WS1/§WS2/§WS4a Acceptance): every over-threshold step emits a bounded
  `Compacted` (no raw-history send); AI-fold cadence is O(run/tail-budget), not per-step; cross-step cache
  hit (no re-summarize when the tail hasn't overflowed); WS4a trim/pass; WS3 findings survive a fold and
  re-surface as a pointer.
- Live corroboration (plan §Verification): re-run `make live_qwen36_compaction_heavy_headless` — summarizer
  input and fold count collapse, sent window stays under limit, model stays productive
  (`finish_reason:"tool_calls"`). Re-run `live_hunyuan3_free_compaction_heavy_headless` — folds rare, no
  summarizer hang.
- No guardrail violated: no `st.msgs` mutation, no calibration change, no ABI/core touch (WS1/WS2/WS3/WS4a
  are extension-only).

## Commit and closeout conventions

- Commit the plan (docs-only) first, then one commit per WI with a `file:line`-anchored rationale that
  names the invariant it preserves (esp. trap #1 "always Compacted" and trap #2 "contiguous tail").
- Follow the repo's commit-trailer convention (see recent `git log`).
- When done, drop a `NOTE-rederivation-implementation-findings.md` here if as-built diverged (e.g. Engine A
  drift verdict, whether you built B, the exact refresh-budget you tuned), add a stale banner to this
  handoff pointing at it, and update the issue's Status.

## Pre-flight (run before WI-1)

```bash
git rev-parse --short HEAD                                   # expect af615cb (or later)
git status --short                                           # commit the PLAN edits first
make compaction_dst && make conformance                      # baseline must be green BEFORE you start
grep -n "result_target_pct\|calibrated_ctx_usage" packages/motoko-ext-compaction-structural/compaction_structural.ail  # confirm sibling plan is live
git log --oneline -20 -- src/core/ packages/                 # anything newer than af615cb here → re-verify anchors
```
