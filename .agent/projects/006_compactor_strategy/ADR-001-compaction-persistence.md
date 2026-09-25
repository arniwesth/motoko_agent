# ADR-001: Compaction persistence — keep the ephemeral (send-only) model, or write compaction back into the session history?

Date: 2026-07-11
Status: **Proposed (stub — decision not yet made)**
Pinned toolchain: AILANG **v0.26.0**; `ailang.lock` → `ailang_version: "v0.26.0"`
Grounded at: branch `arniwesth/mot-38-progress-contract-finalize-guard-extension`, HEAD `bd4ce58`

Relates to:
- `design_docs/planned/m-motoko-conversation-compaction.md:52` — the **decision this ADR revisits**:
  *"If any registered hook returns `Compacted`, the returned `msgs` replaces the input for this step
  only — the session log is unchanged."* (the ephemeral guarantee).
- `../../issues/compaction-rederive-cost-dominates-after-strategy-fixes.md` — the motivating cost: the
  ephemeral model re-derives an ever-growing summary every step (~4.2M billed input tokens on one
  qwen36 run). This ADR is the decision record for whether to keep paying that or go persistent.
- `PLAN-rederivation-context-strategy.md` — the plan that mitigates the cost **within** the ephemeral
  model (WS1 trigger, WS2 cached fold). **This ADR, if it lands persistent, supersedes WS1/WS2.**
- `../004_phase_core_refactor/ADR-001-phase-oriented-core.md` D9 — compaction policy is
  extension-resident; the `PreStepDecision` ABI is the seam. A persistent variant is an **ABI + core**
  change governed by D9.
- `../005_harness_policy_boundary/ADR-001-harness-policy-boundary.md` — treats ephemeral-by-design as a
  settled premise and explicitly parks this question ("a separate NOTE, not this plan").
- `../001_DST/ADR-002-compaction-dst-regrounded-on-phase-core-scaffold.md` +
  `ADR-004-long-qwen-compaction-session-dst.md` — the DST harnesses whose replay semantics depend on the
  session log being un-mutated. **Persistence must not break these** (see Consequences).
- Prior art (read from source 2026-07-11): `earendil-works/pi`
  (`packages/coding-agent/src/core/compaction/compaction.ts`) + `itayinbarr/little-coder` — both
  **persistent**, both targeting Qwen3.6-35B-A3B (Motoko's stress-test model).

---

## Status / how to use this stub

**No decision yet.** This file exists so the fork is tracked rather than floating in a plan. It captures
the question, the options, and the evidence gathered so far. Promote to a real decision (fill §Decision,
flip Status to Accepted/Rejected) when someone owns it. Until then, `PLAN-rederivation-context-strategy.md`
proceeds on the ephemeral assumption.

---

## Context / the question

Motoko's compaction is **ephemeral by design** (doc:52): a pre-step hook returns a `Compacted` payload
used **for the send only** (`session.ail:1660` `compacted_msgs`), while the persisted next-state history
is the **full uncompacted** history (`session.ail:1722` `msgs_with_assistant = st.msgs ++ [assistant_msg]`).
The compaction trigger re-evaluates that ever-growing history every step, so a fresh summary is re-derived
every step — the dominant cost on long tool-heavy runs.

Every other surveyed coding agent (Claude Code, Codex CLI, OpenCode, pi/little-coder) is **persistent**:
the summary replaces the old messages in the session going forward, so nothing is re-derived. They accept
a lossy, non-reversible log; Motoko traded that away for audit / DST replay / un-compaction.

**Question:** keep ephemeral (and mitigate the cost via caching — the plan's WS1/WS2), or adopt a
persistent model (summary written back to `st.msgs`) and delete the re-derivation entirely?

---

## Options

**A. Keep ephemeral; mitigate with caching (the plan's default).** WS1 (trigger on real usage) + WS2
(cache a rolling `{summary, boundary}` in `artifacts`, fold only the delta). Preserves doc:52 exactly;
audit/replay/un-compaction intact. Cost: the ephemeral-port machinery (cache management, boundary
tracking, re-injection each step) — more code than persistence, and the full history still grows unbounded
in `st.msgs` (a separate, parked tradeoff).

**B. Go persistent.** Add a `PreStepDecision` variant the core writes back to `st.msgs` (e.g.
`PersistentCompacted`), matching pi's `CompactionEntry` + `firstKeptEntryId` model: the summary becomes a
real history entry, subsequent turns build on it, next compaction folds only new turns. Deletes WS1/WS2's
caching machinery (the history *is* the cache). Cost: overturns doc:52; must reconcile with DST replay,
un-compaction, and the append-only ledger.

**B′. Persistent with an audit side-channel.** Persist for the live loop **and** keep the pre-compaction
entries in the append-only ledger (not the live context) so audit/replay can reconstruct. This is likely
what makes B compatible with the DST harnesses — pi itself keeps the pre-compaction entries in the session
file and only changes what's *loaded* into context. Worth checking whether Motoko's ledger already affords
this (it is append-only), which would make B far cheaper than "overturns doc:52" implies.

---

## Evidence / open questions to resolve before deciding

- **Is doc:52's guarantee load-bearing in practice?** Which consumers actually rely on the *live session
  log* being un-mutated — DST replay, un-compaction, audit tooling? If B′ (ledger side-channel) satisfies
  all of them, B becomes low-risk. **This is the crux; resolve it first.**
- **DST replay.** `../001_DST/ADR-002` + `ADR-004` replay compaction sessions. Confirm whether they replay
  from the *live* history or from the *ledger* — if the latter, B′ is transparent to them.
- **Un-compaction.** Does any feature actually reconstruct pre-compaction context from `st.msgs`? If not,
  the "un-compaction" benefit of ephemeral is aspirational (cf. the `check-design-docs-before-proposing-adr`
  memory — verify before treating a documented benefit as used).
- **Cost delta.** Quantify: with WS1/WS2 (Option A) landed, is the residual re-derivation cost still large
  enough to justify a core/ABI change? If WS1/WS2 already bring billed input within ~2× of persistent,
  the ADR may resolve to "A is good enough."
- **ABI shape.** B needs ABI addition (a write-back `PreStepDecision` variant) — coordinate with the ABI
  additions in `PLAN-rederivation-context-strategy.md` §ABI additions (this is a *different* addition from
  #1/#2 there, which are tool-result/state-write hooks).

---

## Decision

_Not yet made._ (Fill when owned: chosen option, rationale, and which of WS1/WS2 it supersedes.)

## Consequences

_Pending decision._ Key ones to work through: DST-harness compatibility (must stay green), un-compaction
semantics, unbounded `st.msgs` growth (Option A leaves it; B/B′ can bound the *live* window while the
ledger retains the rest), and whether the structured summary schema + durable evidence store (plan WS2/WS3)
make a lossy persistent summary safe enough.
