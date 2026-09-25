# NOTE-006: Harness Compaction Resilience and Boundary Analysis Under Heavy Tool Payloads

## Context & Purpose
Analysis of the harness runtime context-compaction pipeline (`src/core/phase_vocab.ail`, `scripts/smoke_v2_compaction_tiers.ail`, and `scripts/smoke_compaction_tool_call_id.ail`) under multi-step execution and heavy tool output volumes to map architectural boundaries and failure modes.

---

## Compaction Architecture & Invariants

Motoko manages context pressure via multi-tiered, in-place elision governed by calibrated/estimated usage percentages against the model's context limit:

- **< 70% Usage:** Passthrough with zero modification.
- **70%–85% Usage (Tier 1):** Elides older tool outputs, keeping the last 10 tool outputs intact.
- **85%–95% Usage (Tier 2):** More aggressive reduction, keeping only the last 5 tool outputs intact.
- **≥ 95% Usage (Tier 3 Emergency):** Retains only the last 3 tool results, recovering usage to well below 95% when tool messages dominate.

### Load-Bearing Invariant: `tool_call_id` Preservation
Compaction performs in-place content rewriting (`[output elided...]`) rather than dropping elements from the message list. This guarantees that:
1. Message list cardinality and ordinal alignment remain preserved across compaction passes.
2. The pairing between assistant `tool_calls` and corresponding `tool`-role result envelopes remains intact, preventing provider API `400/422: missing tool_use_id` rejection.

---

## Discovered Harness Weaknesses & Boundary Limits

### 1. Asymmetric Failure on Non-Tool Context Flooding
- **Mechanism:** Compaction exclusively targets `role == "tool"` messages.
- **Failure Mode:** If large volume enters via `user` turns, prompt injections, or extended assistant prose, compaction tiers have no effect. Under ≥ 95% load dominated by non-tool content, the step fails closed with an unrecoverable `compaction_exhausted` error (`test_tier3_exhausted_errs`).

### 2. Silent Context Degradation for Multi-Turn Synthesis
- **Mechanism:** Older tool outputs are overwritten with placeholder markers.
- **Failure Mode:** In workflows requiring information synthesis across long spans (e.g., inspecting modules early and modifying them many steps later), intermediate facts vanish from active working memory. This can induce repeated re-read loops and token churn.

### 3. Character vs. Token Heuristic Divergence
- **Mechanism:** Context pressure calculation relies on heuristic ratio tracking (`char / 4` vs. calibrated provider tokens).
- **Failure Mode:** In high-density payloads (minified code, non-ASCII text, dense JSON), token density exceeds the heuristic, creating a risk that physical context boundaries are breached before Tier 3 compaction triggers.

### 4. Step Budget Discriminator Wire-Coupling
- **Mechanism:** Step exhaustion in `step_machine.ail` emits an `Internal` error code matching the literal `"v2 loop: step budget exhausted"`.
- **Failure Mode:** Because wire compatibility prohibits changing the code to a dedicated `StepBudgetExceeded` type, downstream consumers and TUI layers depend strictly on exact message-string matching, creating a latent classification hazard if error messaging diverges.
