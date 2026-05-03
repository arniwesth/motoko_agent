# Structured Tool-Call Authoring for AILANG (Option 2) — Plan

**Date:** 2026-04-14
**Status:** Draft — primary near-term investment for AILANG validity on Gemma 4
**Suggested branch:** `Structured_Tool_Call_Authoring`

**Target model:** This plan exists specifically to improve AILANG code generation quality on `google/gemma-4-26B-A4B-it` (Gemma 4 MoE, 25.2B total / 3.8B active, 256K context). AILANG is out-of-distribution for Gemma's pretraining and its Python/JS priors actively mislead freehand AILANG emission. This plan sidesteps that by removing AILANG-syntax authoring from the model's responsibilities — the model chooses *content* via structured tool calls, and the dispatcher owns *shape*.

**Transport:** This plan rides the **existing fenced `tool_call` JSON protocol** already used by the read-side author tools (`read_file`, `grep`, `list_dir`, etc. per `Compose_Author_Premise_Tools.md`). It does **not** depend on provider-native tool calling (e.g. OpenAI Responses API tool events). Adopting provider-native tool calling as a quality optimization is deferred to a separate phase / companion plan; see `Native_Tool_Calling_For_Motoko.md` for prior art on that effort.

**Related context:**
- `.agent/research/AILANG_performance_evidence_gates.md` — full research note; see the **"Structured Tool-Call Authoring — Deeper Analysis"** section for lever rationale, tool-surface inventory, granularity tradeoffs, dispatcher responsibilities, and interactions with other levers.
- `.agent/plans/Compose_Author_Premise_Tools.md` — read-side author-tool dispatcher and the fence protocol this plan reuses.
- `.agent/plans/Compose_As_Extension.md` — extension host where the dispatcher lives.
- `.agent/plans/Native_Tool_Calling_For_Motoko.md` — prior-art plan for provider-native tool calling (OpenAI Responses API scope). Treated here as a **future optimization**, not a prerequisite. Was copied in from a prior branch that did not land.
- `.agent/summaries/2026-04-14-compose-author-premise-tools-plan-implementation.md` — current state of the author loop that this plan modifies.
- `.agent/summaries/2026-04-14-compose-regression-investigation-and-hardening.md` — parse-loop and type-loop hardening that this plan aims to make largely redundant for the parse class.
- `ailang-v0.9.0-docs.md` — supplemental AILANG language reference. Runtime introspection (`ailang docs ...`) is the schema source of truth.

---

## Goal

Replace free-text AILANG emission in the Compose author loop with a **structured tool-call authoring** surface (Option 2 — skeleton + free-text bodies). The model invokes tools like `set_module`, `add_import`, `define_func`, `build_block`, `build_match`; the dispatcher accumulates an in-memory program representation and renders canonical AILANG at `finalize()`. Function bodies and expression leaves remain free-text strings that the dispatcher parses on receipt, so parse errors inside bodies are caught at the tool level with structured feedback rather than after whole-snippet rendering.

**Primary success metric:** parse-error rate on finalized snippets drops toward zero on Gemma 4. Type-error rate is expected to stay roughly flat initially (grammars don't fix semantics) and becomes the next frontier.

## Motivation

Current behavior on Gemma 4 is dominated by parse/type loops — the model struggles to produce valid AILANG because AILANG is outside its pretraining distribution. Existing hardening (prompt compaction, parse-loop reset, type-loop reset, targeted-edit retry) helps the tail but does not address the root cause: the model is being asked to satisfy AILANG's syntax, type system, effect system, scope rules, and task semantics **simultaneously**, and breaks down on the first.

Structured tool-call authoring moves syntax and effect-row well-formedness into the dispatcher:
- The shape of valid AILANG becomes a dispatcher invariant.
- Gemma's well-tuned ability to emit structured JSON is exercised instead of its weakest skill (freehand AILANG syntax).
- Python/JS priors help (`add_import(...)` fits them) rather than hurt.
- Errors return as typed, localized, actionable tool-call results, not raw `ailang check` output.

Net: parse errors eliminated by construction; effect-row issues surfaced as dispatcher hints before `ailang check`; retry loops collapse into structured repair calls. Authoritative effect/type outcomes still come from `ailang check` at `finalize()`. Because the transport is the fence protocol (already proven in-codebase by the read-side author tools), none of this requires provider-native tool calling support at the endpoint level — deployment risk is bounded to the same surface we already run on.

## Non-goals

- **Full-AST granularity (Option 1).** Out of scope for this plan. Revisit only if body-level parse errors dominate telemetry after Phase 4.
- **Grammar-constrained decoding.** Deferred (see research note) — requires endpoint control we do not have.
- **Fine-tuning on AILANG.** Explicitly out of scope; orthogonal and higher-cost.
- **Provider-native tool calling.** Not required by this plan. The fence protocol is the primary transport. If native tool calling is adopted later (see `Native_Tool_Calling_For_Motoko.md`), it becomes a drop-in transport swap for the dispatcher interface defined here — a measurable quality optimization, not a capability gate.
- **Replacing the read-only author-tool dispatcher.** Those tools (`read_file`, `grep`, `list_dir`, etc. from `Compose_Author_Premise_Tools.md`) stay as-is. This plan adds a **write-side** tool category alongside them, using the same fence protocol.
- **Breaking changes to ledger event shape.** Same events (`compose_author_tool_call`, `compose_author_tool_result`, `compose_author_ledger_snapshot`) carry the authoring tool calls. New fields may be added additively (e.g. `category: "authoring"` discriminator).

## Assumptions (please confirm before Phase 0)

1. **Prerequisites landed.** `Compose_As_Extension` and `Compose_Author_Premise_Tools` are merged; `src/core/ext/compose/author_loop.ail` multi-turn loop is in place; the fenced `tool_call` JSON dispatcher in `src/core/ext/compose/author_tools.ail` is operational and proven on Gemma 4 for the read-side tools.
2. **Transport reuse.** The fenced `tool_call` JSON protocol from `Compose_Author_Premise_Tools.md` is sufficient to carry authoring tool calls. No provider-native tool calling is required; no new provider capability flag is plumbed at MVP.
3. **Schema source of truth.** Tool schemas for imports, builtins, and effects are derived from runtime introspection (`ailang docs --list` plus per-module docs). Markdown docs (`ailang-v0.9.0-docs.md`) are advisory only. A small regeneration script keeps schemas/manifests aligned with stdlib versions.
4. **Sandbox unchanged.** All authoring is in-memory until `finalize()`, which writes a rendered snippet through the same snippet-store path used today. No new FS surface.
5. **Budget default:** 40 authoring tool calls per snippet, configurable via `AILANG_COMPOSE_AUTHORING_BUDGET`. Separate from the read-tool budget (`AILANG_COMPOSE_AUTHOR_TOOLS_BUDGET`) because authoring calls dominate count.
6. **Default off** on first release (`AILANG_COMPOSE_STRUCTURED_AUTHORING=0`); flip default-on for Gemma-4 model strings in a follow-up after bake-in.
7. **JSON emission reliability on Gemma 4.** Gemma 4 reliably emits well-formed JSON inside fenced blocks at usable rates. This is the only model-side capability assumption and is verified empirically in Phase 0.3 (a small, cheap smoke test — *not* a go/no-go on the plan, but a calibration of expected retry overhead and prompt-shape choices).

---

## Protocol

The plan rides the **existing fenced `tool_call` JSON protocol** already used by the read-side author tools. One action per turn, JSON inside a fenced code block, dispatcher parses post-stream. No new transport.

Each author turn emits exactly one fenced `tool_call` JSON block, which is one of:
1. An **authoring tool call** (surface A/E/composite below) against the in-memory program state, or
2. A **`finalize()`** call, which triggers rendering + `ailang check`, or
3. A **read-side tool call** from the existing dispatcher (`read_file`, `grep`, etc.), unchanged.

Turn-shape policy (deterministic):
- Exactly one fenced `tool_call` block is accepted per turn.
- If zero blocks, multiple blocks, or malformed fence structure are present, reject the turn with `error_class: "invalid_turn_shape"` and do not mutate state.
- If prose exists outside the single valid fence, ignore prose and process the fence.
- If JSON inside the accepted fence is invalid, return parse/validation error and do not mutate state.

The dispatcher (a write-side extension to the existing `author_tools.ail` dispatcher):
- Routes the parsed tool call to the read-side or write-side handler based on `tool_name`.
- Validates each tool call against its JSON Schema before applying.
- Applies valid calls to the in-memory program state (atomic per call — failed calls do not mutate state).
- Returns a structured response in the next turn's tool-result message; failures carry `error_class`, `detail`, and where possible `suggestion` / `did_you_mean`.
- Emits the same `compose_author_tool_call` / `compose_author_tool_result` ledger events as the read-side tools, with a `category: "authoring"` discriminator.

**Future optimization (not in this plan):** the same dispatcher interface can be driven by provider-native tool-call events (OpenAI Responses API tool events, Anthropic `tool_use`, Gemini function calls). That swap is the scope of `Native_Tool_Calling_For_Motoko.md` and is treated here as a quality optimization on top of an already-working fence pipeline, not a precondition.

Termination:
- **Normal:** model calls `finalize()`, dispatcher renders + checks, returns `{ok: true, snippet: "..."}` or `{ok: false, errors: [...]}`. On `ok: true`, authoring ends.
- **Error on finalize:** returned errors are presented to the model which may call repair tools (surface E below) or mutators (`replace_func_body`, etc.) and retry `finalize()`.
- **Budget exhausted:** loop emits `structured_authoring_budget_exhausted` and follows the configured fallback policy.

Fallback policy (specified for MVP):
- `AILANG_COMPOSE_STRUCTURED_AUTHORING_FALLBACK_AFTER=3` by default.
- While structured authoring is enabled, remain structured-first until either:
  - `N` consecutive failed `finalize()` attempts are reached, or
  - authoring budget is exhausted.
- If fallback is enabled, the remainder of the Compose invocation uses existing free-text authoring.
- If fallback is disabled (`AILANG_COMPOSE_STRUCTURED_AUTHORING_FALLBACK_AFTER=0`), terminate with structured-authoring failure when budget/failure thresholds are hit.

---

## Tool surface (Phase 1 initial set)

Grouped per research note surface categories. Names are provisional; finalize in Phase 0.

### A. Program skeleton
- `set_module(path: string)`
- `add_import(module: string, symbols: [string], alias: string | null)`
- `add_type_alias(name, type_params, definition)` — `type X = ...`
- `define_type(name, type_params, constructors, derives)` — ADTs
- `define_func(name, params, return_type, effects, body, is_pure, is_export)` — **body is free-text AILANG** parsed on receipt
- `set_main(effects, body)` — convenience for the common entry-function shape
- `finalize()` → `{ok, snippet | errors}`

### B. Block / expression helpers (optional in MVP)
Deferred to Phase 3 unless Phase 4 measurement shows body-parse errors dominate. When added, mirror the surface listed in the research note (§"Tool surface — what to expose", B/C/D).

### E. Repair tools (Phase 3)
- `replace_func_body(name, new_body)`
- `add_effect_to_func(name, effect)` / `remove_effect_from_func(name, effect)`
- `add_import(...)` also doubles as import-repair since it is idempotent
- `rename_var_in_body(func_name, from, to)`

### Composite / templates (Phase 3+)
- `scaffold_main(effects, imports, body)` — collapses `set_module` + `add_import`* + `set_main` into one call for the common case. Emits the same underlying state mutations; purely ergonomic.

---

## Dispatcher responsibilities (Phase 1)

1. **Schema validation** at provider boundary (JSON Schema).
2. **Reference integrity** — inline AST nodes reference only previously-built or inline handles.
3. **Import / symbol validation** against a stdlib manifest derived from `ailang docs --list`. Unknown symbols return `{error_class: "unknown_symbol", did_you_mean: [...]}`.
4. **Effect-row hinting (best-effort, non-authoritative)** — effect names are from the fixed alphabet `{IO, FS, Net, Env, AI, Debug, Process, SharedMem, Stream}`. Dispatcher may emit `effect_hint_mismatch` from direct-call/import heuristics, but does not reject `finalize()` on hints alone.
5. **Scope checking (best-effort)** — free-text bodies are parsed; variables referenced but not bound in the accumulated block/function scope return `error_class: "unbound_identifier"`.
6. **Rendering** — canonical pretty-printer emits AILANG from internal state. Guarantees `{`/`;` vs `=`/`in` discipline and import ordering.
7. **`ailang check` at finalize** — the real parser/type-checker is authoritative. Any surviving parse error on finalize is a dispatcher bug; log it for investigation. Type/effect checking errors returned by `ailang check` are authoritative (`effect_check_error`, type errors, etc.) and surfaced as structured errors (see Phase 3 repair tools).

---

## Phases

### Phase 0 — Inventory and schema draft (no code changes)
- **0.1** Inventory Gemma-4 failure modes on a recent Compose batch: run `scripts/analyze_compose_meta.py` against `.motoko-store/snippets` and classify failures (parse vs. type vs. runtime). Captures the baseline against which Phase 4 success will be measured.
- **0.2** Draft tool schemas as JSON Schema files under `src/core/ext/compose/authoring/schemas/`. One file per tool.
- **0.3** **Fence-JSON smoke test on Gemma 4** (calibration, not a gate). Issue ~10 author-style prompts that ask Gemma 4 to emit a fenced `tool_call` JSON block matching one of the surface-A schemas. Measure: (a) JSON-parse success rate, (b) schema-validation success rate, (c) one-action-per-turn discipline (extra fences, prose-after-fence, etc.). Record results in the decision log. The fence dispatcher is already proven on Gemma 4 for the read-side tools, so this is a sanity check on schema cognitive load — not a go/no-go on the plan.
- **0.4** Timeboxed feasibility spike (0.5 day): confirm whether `ailang check` can emit machine-consumable AST for round-trip/importer reuse.
- **0.5** Agree on naming and surface scope with reviewers. Open a short decision log.

**Exit criteria:** baseline failure distribution captured; schemas drafted; fence-JSON smoke test results recorded with parse-rate and schema-validation-rate numbers; AST-export feasibility decision documented; decision log opened.

### Phase 1 — Dispatcher and renderer (backend-only, no author-loop integration yet)
- **1.1** `src/core/ext/compose/authoring/state.ail` — internal program AST plus accumulator state.
- **1.2** `src/core/ext/compose/authoring/dispatcher.ail` — dispatches surface A tools, validates, mutates state.
- **1.3** `src/core/ext/compose/authoring/render.ail` — pretty-prints state → canonical AILANG source.
- **1.4** `src/core/ext/compose/authoring/stdlib_manifest.ail` — known imports and their symbols; generated from `ailang docs --list` output (script in `scripts/gen_stdlib_manifest.py`).
- **1.5** Validation strategy by track:
  - **Track A (only if AST export is confirmed in Phase 0.4):** round-trip test on a curated corpus (parse/import → render → `ailang check`), idempotent on supported productions.
  - **Track B (default / required fallback):** golden tests from curated tool-call sequences → render → `ailang check`, plus canonical-render snapshots.
- **1.6** Error taxonomy: define `error_class` enum and expected response shapes.
- **1.7** Adversarial protocol tests at dispatcher boundary: malformed JSON, multiple fences in one turn, prose outside fence, unknown tool, missing args, duplicate/retry idempotency, and bad handle references.

**Exit criteria:** dispatcher passes schema validation on a suite of hand-written tool-call sequences; Track A *or* Track B validation is green (Track B required if no AST export); adversarial protocol tests pass; unit tests green.

### Phase 2 — Author-loop integration behind a feature flag
- **2.1** Add `AILANG_COMPOSE_STRUCTURED_AUTHORING` env flag (default off). No new provider capability flag; transport is the existing fence dispatcher.
- **2.2** Extend `src/core/ext/compose/author_tools.ail` with the write-side tool-name routing — same fence parser, same per-turn discipline, new handler entry points. Read-side tools remain available in the same surface so the model can mix `read_file` calls with authoring calls in one session.
- **2.3** `src/core/ext/compose/author_loop.ail` — when the flag is on, swap the authoring system prompt to one that documents the surface-A tool schemas and instructs the model to author exclusively via fenced `tool_call` JSON blocks. The loop drives the same fence-parse → dispatch → tool-result feedback cycle already used for read-side tools.
- **2.4** Ledger events `compose_author_tool_call` / `compose_author_tool_result` emit with `category: "authoring"` and `tool_name`; snippet-store sidecar includes the authoring trace.
- **2.5** Fallback path unchanged when flag is off: existing free-text author path runs.
- **2.6** When flag is on, apply the explicit fallback policy defined in Protocol (`AILANG_COMPOSE_STRUCTURED_AUTHORING_FALLBACK_AFTER`, plus budget-triggered fallback/termination behavior).
- **2.7** Emit `structured_authoring_budget_exhausted` when the authoring budget is hit.

**Exit criteria:** with the flag on and Gemma 4 configured, a committed fixed 20-task smoke suite passes these gates: JSON-parse success ≥ 95%, schema-validation success ≥ 90%, finalize parse-error rate ≤ 5%, and sidecar/ledger traces present on all runs. Evaluation config (model string, temperature, retry limits, and budgets) is pinned in-repo, and metrics are reported across at least 2 repeated runs. Flag-off fallback path still works with no regressions.

### Phase 3 — Repair tools and error quality
- **3.1** Implement surface E (repair tools) behind the same dispatcher.
- **3.2** Improve `error_class` coverage based on Phase 2 telemetry; add `suggestion` / `did_you_mean` fields where the dispatcher has enough context.
- **3.3** Expose repair tools to the model after any failed `finalize()` call; stretch goal: expose them progressively (skeleton tools first, then repair after first failure) if the provider supports progressive tool exposure.
- **3.4** Add a composite `scaffold_main` for the common Compose analyze/summarize entry pattern.

**Exit criteria:** repair tools demonstrated on a synthetic repair-case fixture; `error_class` taxonomy stable.

### Phase 4 — Measurement and rollout decision
- **4.1** Re-run the Phase 0 measurement pass with structured authoring enabled on a matched Gemma-4 batch.
- **4.2** Primary metrics:
  - Parse-error rate on finalized snippets (target: < 2%)
  - First-attempt success rate (target: ≥ Phase 0 free-text baseline + 25 pp, tentative)
  - Mean authoring tool calls per successful snippet (target budget: ≤ 15 for Option 2 surface A + finalize)
  - Failed tool calls per snippet (repair efficiency)
  - Type-error rate (expected: ~flat; tracked to guide the *next* plan)
- **4.3** Secondary: latency, token cost, and end-to-end compose turnaround time.
- **4.4** Rollout decision:
  - If primary metrics clear: flip `AILANG_COMPOSE_STRUCTURED_AUTHORING=1` for Gemma-4 model strings by default in a follow-up; keep other providers on the existing path unless measured separately.
  - If parse-error rate does not collapse: investigate whether body-level parse errors dominate, and if so, prioritize Phase 5 (add surface B builders).
- **4.5** Decide on the next lever: error→hint table scope reduction, retrieval of tool-call sequences instead of snippets, or exploratory Phase 5.

**Exit criteria:** measurement captured; rollout decision logged; follow-up plan scoped.

### Phase 5 — Conditional: finer expression builders (only if Phase 4 indicates)
Add surface B/C/D builders (block / expression / pattern / type construction) from the research note. Keep existing free-text body path as a fallback for constructs that remain awkward to express as tool calls (contracts, complex `deriving`, existential types).

### Phase 6 — Optional: provider-native tool-call transport (companion plan)
Out-of-scope here, but called out for sequencing clarity. After Phases 1–4 land and the dispatcher interface is stable, the fence transport can be **drop-in-replaced** by provider-native tool-call events (OpenAI Responses API tool events, Anthropic `tool_use`, Gemini function calls). That work — capability flag plumbing, provider adapter normalization, idempotency keys, ledger event extension — is the scope of `.agent/plans/Native_Tool_Calling_For_Motoko.md` (prior-art plan, not yet landed). It becomes a **measurable quality optimization** at that point: same dispatcher surface, same schemas, same ledger shape, possibly better JSON-emission discipline and lower per-turn token overhead. Treat it as a follow-up only if Phase 4 telemetry shows fence-transport overhead is a meaningful bottleneck.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Gemma 4 emits malformed JSON inside fences under load | Already mitigated by the existing read-side fence dispatcher; calibrate parse-rate in Phase 0.3 smoke test; cap retries per call; structured error response on parse failure |
| Schema cognitive load on the model | Start with surface A only (~7 tools); add B/E progressively based on telemetry |
| Latency from turn count | Composite `scaffold_main` for the common case; keep bodies free-text under Option 2 |
| Free-text body still produces parse errors | Dispatcher parses and rejects at tool level with structured error; repair tools close the loop before `finalize()` |
| Dispatcher diverges from real AILANG parser | Round-trip corpus test (Phase 1.5) + real `ailang check` at finalize as authoritative check |
| Schema drift across AILANG versions | Schemas regenerated from `ailang docs --list`; per-release CI job |
| Effect hinting is wrong (false positives/negatives) | Keep effect inference non-authoritative; label as `effect_hint_mismatch`; rely on `ailang check` for authoritative effect errors |
| Model embeds raw AILANG inside string fields under pressure | Dispatcher parses long string fields and rejects unparseable ones |
| Telemetry volume from many small tool calls | Authoring events tagged `category: "authoring"` for filtering; single consolidated user-visible event per snippet |
| Provider tool-call shape differences | Not applicable at MVP — fence transport is provider-agnostic. Becomes relevant only if Phase 6 (native tool calling) is later adopted, where the adapter layer in `Native_Tool_Calling_For_Motoko.md` normalizes shapes |
| Ledger / budget interaction with existing read-tool budget | Separate budget key (`AILANG_COMPOSE_AUTHORING_BUDGET`) |

---

## Open questions to resolve before or during Phase 0

1. AST handle representation — string IDs referenced across turns, or inline nested JSON composition? Probably both: inline for coarse tools, IDs for edits.
2. How much semantic validation in-dispatcher vs. deferred to `ailang check`? Current proposal: parse-level and scope-level in-dispatcher; type inference at finalize.
3. Composite template tool inventory — beyond `scaffold_main`, which other common shapes warrant first-class tools? Revisit after Phase 4 telemetry.
4. Fence-transport limits on Gemma 4 — JSON-parse rate at higher schema complexity, max useful nesting depth in tool-call arg JSON, and any prompt-shape sensitivities (system-message vs. user-message tool docs). Calibrate in Phase 0.3 smoke test.

---

## Future options from runtime observations

These are explicitly deferred options captured from post-implementation runtime behavior (`author_no_action`, `author_turn_limit`) and can be promoted into a follow-up phase once prioritized.

### Options to reduce `author_no_action`

1. Make fallback faster:
   - Lower malformed/no-action tolerance before switching mode (for example, from 3 to 2).
2. Tighten prompt contract:
   - Place required output format at prompt tail, include one valid and one invalid tool-call example, and explicitly ban prose-only turns.
3. Add auto-repair for near-miss outputs:
   - Recover JSON lacking fences or minor wrapper noise once before counting as no-action.
4. Forced first action bootstrap:
   - Require first turn to emit a minimal tool-call template (model only fills args).
5. Increase determinism:
   - Lower author-loop temperature/top-p to reduce prose drift.
6. Stronger no-action feedback:
   - Return a compact structured error that states the exact required next-turn shape.
7. Last-resort mode bypass:
   - After N no-action events, bypass loop constraints and run one direct free-text author pass for the attempt.

### Options to reduce `author_turn_limit` hits (without raising turn cap)

1. Recover near-miss structured outputs:
   - Convert almost-valid turns into actionable calls rather than burning turns.
2. Early action plan enforcement:
   - Force first turns to establish skeleton state (`set_module`, imports, function shell) before open-ended authoring.
3. Duplicate-call suppression:
   - Expand dedupe to all non-mutating repeats (not just repeated reads) and return cached/no-op hints.
4. Progressive tool exposure:
   - Start with skeleton + `finalize`, unlock repair tools after first failed finalize.
5. Turn-level stop rules:
   - If repeated non-mutating calls are detected, force next action to be `finalize` or a mutating repair tool.
6. Strong finalize cadence:
   - Require/bias toward `finalize` once minimum viable state exists (for example main + body present).
7. Better structured finalize errors:
   - Emit compact actionable fields (`target_func`, `missing_effect`, `unknown_symbol`) instead of raw-only checker text.
8. Intent-specific template pre-seeding:
   - Initialize state from known-good analyze/summarize skeletons.
9. Lower author-loop randomness:
   - Use conservative sampling to reduce dithering and format drift.
10. Automatic mode switch heuristics:
   - If structured mode does not reach finalize within N turns, switch mode for the remainder of the attempt.

---

## Relationship to the broader research note

This plan implements **lever 2** from `.agent/research/AILANG_performance_evidence_gates.md`. It is the highest-leverage lever that is fully deployable on currently-available hosted endpoints (lever 1, grammar-constrained decoding, is deferred pending endpoint control). The other levers in the research note (retrieval few-shot, error→hint table, conditional thinking mode, fine-tuning) remain candidates for follow-up plans; several are partially subsumed by the dispatcher's structured-error responses and may scope down as a result of this work.

See the research note for full rationale on why this lever fits Gemma 4 specifically, the granularity-tradeoff analysis behind choosing Option 2, and interactions with the other levers.
