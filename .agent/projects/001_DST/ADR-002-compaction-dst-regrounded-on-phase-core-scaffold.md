# ADR-002: Compaction DST, re-grounded on the phase-core scaffold

Date: 2026-07-06
Status: Proposed
Pinned toolchain: AILANG **v0.26.0** (commit `3b52a24`); `ailang.lock` → `ailang_version: "v0.26.0"`

Relates to:
- `001_DST/ADR-001-deterministic-simulation-testing-architecture.md` (this project) — the original
  DST architecture, authored **2026-06-27 against the pre-refactor loop**. This ADR **supersedes its
  compaction sections** ("Initial Scenario Families → Compaction", the compaction canonical ids, and
  the compaction-specific findings R5/R15) and re-grounds them on the shipped phase-core
  architecture. ADR-001's layer model, harness-boundary (PR #76) scenarios, and CI discipline are
  retained by reference; only the compaction design is re-pointed.
- `004_phase_core_refactor/ADR-001-phase-oriented-core.md` **D9** — the operator decision that made
  compaction *policy* extension-resident (core keeps only the measurement scaffold; the elision
  ladder, tiers, and AI summarization live in `motoko_ext_compaction_structural`; actual-token
  gating is deferred to ABI v3 `ExtCtx.telemetry`). This ADR targets the architecture D9 produced.
- `004_phase_core_refactor/ADR-002-send-gate-and-dst-for-system-prompt-and-overflow.md` — landed the
  typed send-gate (`seal_compacted_payload`) and the ledger observable (`provider_call_prepared`
  carrying `system_prefix_chars`). This ADR **reuses that ledger as the DST recorder** instead of
  building the new one 001_DST/ADR-001 proposed.
- `.agent/research/DST/deterministic-simulation-testing-for-agent-loop-compaction.md` — the
  2026-06-27 research draft. Superseded in the same way as 001_DST/ADR-001; its 8 scenarios are
  reconciled against the current architecture in the de-duplication map below.
- PR **#75** (`fix(compaction): reliable triggering`) — the incident whose bug classes this DST is
  meant to turn into standing law.

---

## TL;DR

The phase-core refactor **landed the very infrastructure** 001_DST/ADR-001 was designed to build,
and **removed from source** the actual-token machinery its compaction scenarios asserted over. So
this ADR is mostly *subtractive*: it retires the stale recorder/constants/headroom design and
re-points the surviving invariants at what shipped.

**Decision:**

1. **The ledger is the recorder.** DST asserts over the existing phase-core ledger
   (`provider_call_prepared` with `system_prefix_count`/`system_prefix_chars`, and the `error`
   event), not a new provider-call recorder. This dissolves 001_DST/ADR-001's hardest open findings
   (R4 trace format, R8 recorder seam) rather than resolving them.
2. **Scope split (D1).** DST the **estimate ladder that ships today** now, as standing Layer-1 law,
   reusing the `phase_c_l1_scenarios.ail` harness. **Specify** the actual-token / qwen-threshold DST
   precisely but **gate it** on the un-landed ABI v3 `ExtCtx.telemetry` seam plus a fake `ai_step`
   port. DST progress is not blocked on the ABI build.
3. **Qwen enters as an injected `limit` (D2).** There is no pure limit function — the only source is
   the effectful `catalog_context_limit_for` (`{Env, FS}`) — so qwen in a pure scenario = the
   model-string label plus its `262144` limit (`.motoko/model-catalog.json:43`) passed as the `limit`
   int to `compact_step_with_limit(msgs, model, limit)`. One small effectful conformance scenario
   guards the `qwen → 262144` catalog binding itself.

The estimate-path scenarios are shippable under `--caps IO` with no ABI change; the actual-token
half is documented as a follow-on that unblocks when D9's ABI v3 lands.

---

## Context

"DST for compaction with the qwen model" reads, from PR #75, as a request to prove that **actual
provider `input_tokens` from step N drive compaction before step N+1** — the qwen window (262144),
the 75k output headroom, and the 60/75/85 actual-token tiers. That behavior **no longer exists in
the codebase.** The phase-core refactor (004 ADR-001 D9) dissolved it, and 001_DST/ADR-001's own
2026-07-03 amendment (finding R5) records the removal:

> "the actual/estimate split … has since been **removed from source** … `OUTPUT_HEADROOM`/`75000`,
> the 60/75/85 actual tiers, `compact_step_actual`, and `last_input_tokens` have no referent in
> `src/core`. Actual-token gating is now compactor-extension policy per phase-core D9 (ABI v3
> `ExtCtx.telemetry`) … `context_limit_for` returns 0 for every model."

Writing scenarios against the research draft or 001_DST/ADR-001 unamended would assert over dead
concepts. This ADR re-establishes what is real at HEAD and splits the work accordingly.

## Investigation findings (grounded at HEAD, toolchain v0.26.0 / `3b52a24`)

1. **The shipped compactor is estimate-only.**
   `packages/motoko-ext-compaction-structural/compaction_structural.ail` (module
   `sunholo/motoko_ext_compaction_structural/compaction_structural`) is a single estimate ladder:
   `elide_tier_pct()=70` (`:14`), `elide_hard_tier_pct()=85` (`:16`), `emergency_pct()=95` (`:18`),
   keep-lasts `10/5/3/1` (`:20-26`), `elide_old_tool_results` (`:72`),
   `compact_step_with_limit(msgs, model, limit)` (`:90`), and the hook entry
   `compact_for_pre_step(ctx, msgs)` (`:117`) which gates on `usage_percent_with_limit(msgs,
   ctx.context_limit)` — **never on actual tokens**. All tier constants are already
   `export pure func`, so DST imports them; no fixture may duplicate a threshold literal.

2. **The ABI v3 telemetry seam is not landed.** The extension consumes `ExtCtx` from
   `pkg/sunholo/motoko_ext_abi/types` at **ABI v2.2.0** (`ailang.toml:7`, `ailang.lock:43`). That
   `ExtCtx` — mirrored in-tree at `src/core/ext/types.ail:11` — carries `context_limit` but **no
   `telemetry` / `last_input_tokens` field**. The actual-token-gated policy D9 promised therefore has
   no seam to run through, and no code references it. Adding it is an ABI major bump (registry
   publish), not an in-tree edit.

3. **The ledger already is the recorder.** 004 ADR-002 shipped `provider_call_prepared` carrying
   `system_prefix_count` and `system_prefix_chars`, emitted by the single send-gate authority
   (`seal_compacted_payload`, `src/core/phase_vocab.ail`), plus the typed `error` event. This is
   exactly the normalized boundary trace 001_DST/ADR-001 proposed to build with a bespoke
   `dispatch_step` recorder (its R8 self-contradiction: "recorder must not change production
   behavior" vs "production-safe seams must be added"). The recorder question is moot: the trace
   exists and is production.

4. **Much of the old invariant list is already core-DST law.** `scripts/phase_c_l1_scenarios.ail`
   already runs 12/12 under `--caps IO`, including system-prefix pinning (sealed `CompactableSegment`
   cannot hold system messages), `compactor_chain_order_is_registry_order`,
   `invalid_stage_skipped_chain_continues`, `oversized_payload_rejected` /
   `actual_token_pressure_defers_to_seal` (the seal exhaustion gate), and `empty_system_prompt_rejected`.
   The genuinely-uncovered residue is the **extension's own policy** — the estimate tier ladder and
   the emergency recovery/exhaustion nuance — plus everything actual-token.

5. **The only limit source is the effectful catalog — there is no pure limit function.** The pure
   `context_limit_for` the 2026-07-03 amendment referred to has since been **deleted entirely**; it
   has no definition at HEAD (verified: no `func context_limit_for` in `src/`). The sole limit source
   is `catalog_context_limit_for(model)` (`src/core/context_usage.ail:50`), effect row `{Env, FS}`,
   reading `.motoko/model-catalog.json` where `"ollama/qwen3.6:35b-a3b-mxfp8": 262144` (`:43`); it is
   the live limit for every send (`rpc.ail:106,:212`; `session.ail:972,:994,:1389`). A pure scenario
   cannot call it, so injecting qwen's limit is **mandatory**, not merely preferred (D2).

## Decision drivers

- Don't assert over removed concepts. Every DST invariant must have a referent at HEAD.
- Reuse the phase-core ledger and the `phase_c_l1` harness; do not build a parallel recorder or a
  second scenario framework (001_DST/ADR-001 "use existing seams first").
- Import the extension's exported tier constants; never duplicate a threshold literal in a fixture
  (the surviving, amended form of 001_DST/ADR-001 R5).
- Keep DST decoupled from the ABI v3 build: an estimate-path guard has standing value now and must
  not wait on a registry publish.
- Layer-1 scenarios run under `--caps IO`, pure, no network, no registry hydration — matching the
  proven `phase_c_l1` gate class.

---

## Decision detail

### 1. The ledger is the DST oracle (retire the recorder)

DST reads the phase-core ledger events already emitted by the send-gate authority:
`provider_call_prepared` (present exactly on calls that proceed; carries `system_prefix_chars`) and
`error` (`code: "SystemPromptEmpty"` on the rejected path). Assertions match structured fields
(`code`, `system_prefix_chars`), never message text. 001_DST/ADR-001's Provider-Call Recording
Contract (its §"Core Components", findings R4/R8) is **withdrawn**: the trace format is the shipped
schema-v1 KV projection; the seam is the existing emit sites; there is no new production change to
justify.

### 2. Scope split — estimate-path now, actual-token specified-but-gated (D1)

**Land now (Layer-1, `phase_c_l1_scenarios.ail` style, `--caps IO`, pure):** scenarios over the
extension's exported pure funcs and the core seal gate, with the qwen limit injected. These become
standing law for the compactor that actually ships.

**Specify but gate:** the actual-token scenarios and the #75.3 summarizer scenario require (a) ABI v3
`ExtCtx.telemetry` and (b) a fake `ai_step` port. This ADR fixes their canonical ids and invariants
so they are implementable the day the seam lands, and names the seam as the single blocker. No DST
gate depends on the ABI build until then.

### 3. Qwen as an injected limit; one catalog-binding guard (D2)

Pure scenarios pass `262144` as the `limit` argument and `"ollama/qwen3.6:35b-a3b-mxfp8"` as the
model label. Separately, one small `{Env, FS}` scenario asserts
`catalog_context_limit_for("ollama/qwen3.6:35b-a3b-mxfp8") == 262144`, so the `qwen → 262144` binding
is guarded in exactly one place and the pure scenarios' injected constant is not a free-floating
magic number.

### 4. Proposed scenarios

**Estimate-path (implement now):**

- **`compaction.estimate_tier_ladder_qwen`** — `compact_step_with_limit(msgs, "ollama/qwen…", 262144)`
  across the tiers, asserting against the *imported* constants: `< elide_tier_pct()` ⇒ no elision;
  `>= elide_tier_pct()` ⇒ keep-last `elide_keep_last()`; `>= elide_hard_tier_pct()` ⇒ keep-last
  `elide_hard_keep_last()`; `>= emergency_pct()` ⇒ emergency path.
- **`compaction.tool_shape_preserved_by_elision`** — `elide_old_tool_results` preserves list length
  and order, every `tool_call_id`, assistant `tool_calls` `id`/`name`/`arguments`, leaves non-tool
  messages untouched, and preserves the recent tier verbatim.
- **`compaction.emergency_recovers_then_exhausts`** — the emergency ladder tries keep-last-3 then
  keep-last-1 and **recovers** tool-heavy overload; it returns `Err("compaction_exhausted: …")` only
  when non-tool content keeps the estimate `>= emergency_pct()` after elision (the amended
  001_DST/ADR-001 R15 nuance: elision never touches non-tool content).
- **`compaction.compactor_input_excludes_system`** — belt-and-suspenders over the sealed segment:
  `compact_for_pre_step` / the chain never receives a `role == "system"` message.
- **`compaction.catalog_limit_qwen`** (`{Env, FS}`) — the single catalog-binding guard from D2.

**Gated on ABI v3 `ExtCtx.telemetry` + fake `ai_step` port (specify only):**

- **`compaction.actual_tokens_drive_next_step`** — when telemetry `last_input_tokens > 0`, tier
  selection uses the actual value, not the char estimate.
- **`compaction.actual_tokens_small_context_fail_open`** — `effective <= 0` (limit at/below headroom)
  fails open in the actual path (the estimate half — `limit <= 0` ⇒ `Ok` — is already unit-tested at
  `phase_vocab` `test_seal_compacted_payload_fail_open_limit_zero`).
- **`compaction.summarizer_uses_agent_model`** (#75.3) — the AI summarizer runs against the agent's
  own model (qwen locally) via an injected fake `ai_step` port, never a dead cloud default.

### 5. De-duplication map (do not re-implement)

| Old canonical id (001_DST/ADR-001 / research draft) | Status at HEAD |
|---|---|
| `compaction.system_messages_hidden_from_compactors` | Structurally guaranteed (sealed `CompactableSegment`); a thin explicit guard is `compactor_input_excludes_system` above, nothing more |
| `compaction.provider_payload_vs_uncompacted_history_pressure` | **Covered** by `project_prep_vs_uncompacted_history_pressure` + `actual_token_pressure_defers_to_seal` |
| `compaction.emergency_exhaustion_estimate_gated` | Seal half covered by `oversized_payload_rejected`; the **extension** emergency ladder is new (`emergency_recovers_then_exhausts`) |
| `compaction.actual_tokens_drive_next_step` | **Gated** (no telemetry seam) |
| `compaction.actual_tokens_small_context_fail_open` | Estimate half unit-tested; actual half **gated** |

## Out of scope

- **Landing ABI v3 `ExtCtx.telemetry`** and the fake `ai_step` port. Named as the blocker for the
  gated scenarios; owned by a separate build WI, not this DST work.
- **Re-homing the 60/75/85 actual tiers + headroom** into the extension. That is the ABI-v3 build,
  not DST.
- **#75.1** (chars/4 over-count) beyond what `estimate_tokens_messages` unit tests already assert.
- **Harness-boundary (PR #76) DST.** Retained from 001_DST/ADR-001; the in-core symptom is already
  guarded by 004 ADR-002's `empty_system_prompt_rejected`.

## Acceptance criteria

1. The five estimate-path scenarios run green under `ailang run --caps IO --entry main
   scripts/phase_c_l1_scenarios.ail` (or a sibling harness), no network, no registry hydration.
2. Each scenario asserts against **imported** extension constants, not literals; a grep proves no tier
   threshold is hardcoded in the scenario file.
3. `emergency_recovers_then_exhausts` distinguishes recovery (tool-heavy) from exhaustion (non-tool
   content), and names its id + first failed invariant on failure (the phase-C reporting contract).
4. `catalog_limit_qwen` proves `qwen → 262144` in one place; the pure scenarios reference that limit,
   not a second copy.
5. The three gated scenarios are specified with ids + invariants and marked blocked-on-ABI-v3; none
   is registered in a live harness list until the seam lands.
6. No scenario depends on effect-handler mocking, real providers, or a bespoke provider-call recorder.

## Consequences

Positive: the compactor that actually ships gains standing `--caps IO` regression law; the DST design
stops asserting over removed concepts; the ledger's role as the trace oracle is made explicit,
collapsing the old recorder findings; the actual-token work has a precise, ready spec the moment ABI
v3 lands.

Negative / accepted: the headline PR #75 behavior (actual tokens beat estimate) remains **untested
until the ABI seam is built** — this ADR makes that gap explicit rather than papering over it with
scenarios that would assert over dead code. The qwen limit is injected in pure scenarios (guarded
once by `catalog_limit_qwen`), a deliberate seam between pure policy and the effectful catalog.

## Rejected alternatives

- **Write the actual-token/qwen scenarios now** (per the research draft / unamended ADR-001) —
  rejected: `compact_step_actual`, `last_input_tokens`, the 60/75/85 tiers, and the 75k headroom have
  no referent at HEAD; the scenarios would not compile or would assert over nothing.
- **Build a provider-call recorder around `dispatch_step`** (ADR-001 §Provider-Call Recording) —
  rejected: the phase-core ledger already emits the normalized boundary trace; a second recorder
  duplicates it and reintroduces the R8 production-change tension.
- **Block all compaction DST on landing ABI v3 first** — rejected: couples standing regression value
  for the shipped estimate compactor to a cross-repo registry publish; D1 decouples them.
- **Duplicate tier thresholds as fixture literals** — rejected: the extension exports them as pure
  funcs; import them (amended ADR-001 R5).

## Decision log

- **D1** (2026-07-06): DST the **shipped estimate ladder** now; **specify but gate** the actual-token
  and summarizer scenarios on ABI v3 `ExtCtx.telemetry` + a fake `ai_step` port. DST is not blocked on
  the ABI build.
- **D2** (2026-07-06): qwen enters pure scenarios as an **injected `262144` limit** + model label;
  one effectful `catalog_limit_qwen` scenario guards the catalog binding.
- **D3** (2026-07-06): the **phase-core ledger is the DST recorder**; 001_DST/ADR-001's bespoke
  recorder and its R4/R8 findings are withdrawn.
- **D4** (2026-07-06): supersede the **compaction sections** of 001_DST/ADR-001 (canonical ids, R5/R15
  compaction findings); retain its layer model, harness-boundary scenarios, and CI discipline by
  reference.

## Grounding and anchor log (HEAD, v0.26.0 / `3b52a24`)

- Extension: `packages/motoko-ext-compaction-structural/compaction_structural.ail` — tiers `:14/:16/:18`,
  keep-lasts `:20-26`, `estimate_tokens_messages:32`, `usage_percent_with_limit:37`,
  `elide_old_tool_results:72`, `compact_step_with_limit:90`, `compact_for_pre_step:117`; ABI dep
  `ailang.toml:7` = `2.2.0`, `ailang.lock:43`.
- ABI `ExtCtx` (no `telemetry`): consumed from `pkg/sunholo/motoko_ext_abi/types` (registry cache,
  ABI 2.2.0); in-tree mirror `src/core/ext/types.ail:11`.
- Core scaffold: `src/core/compaction.ail` `estimate_tokens_messages:17`, `usage_percent_with_limit:25`,
  `exhaustion_pct:30`; send-gate `src/core/phase_vocab.ail` `seal_compacted_payload` + `SealError`
  (post 004 ADR-002); `catalog_context_limit_for:50` in `src/core/context_usage.ail` (`{Env, FS}`),
  live at `rpc.ail:106,:212` and `session.ail:972,:994,:1389`. No pure `context_limit_for` exists
  (deleted; the 2026-07-03 amendment's "returns 0" claim is itself stale).
- Model catalog: `.motoko/model-catalog.json:43` → `"ollama/qwen3.6:35b-a3b-mxfp8": 262144`.
- Existing L1 harness: `scripts/phase_c_l1_scenarios.ail` (12 scenarios, `--caps IO`); scenario-builder
  + `main` list pattern to extend.
- Superseded: `001_DST/ADR-001` compaction sections; `.agent/research/DST/…-agent-loop-compaction.md`.
- **Re-verify before implementing:** `tools/code-graph/extract.sh` (graph was stale at authoring from
  the 004 ADR-002 edits); confirm the extension anchors and the ABI version have not drifted.
