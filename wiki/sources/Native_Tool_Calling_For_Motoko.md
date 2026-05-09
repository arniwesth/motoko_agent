# Structured Tool-Call Authoring for AILANG (Option 2) — Plan

**Date:** 2026-04-14
**Status:** Draft — primary near-term investment for AILANG validity on Gemma 4
**Suggested branch:** `Structured_Tool_Call_Authoring`

**Target model:** This plan exists specifically to improve AILANG code generation quality on `google/gemma-4-26B-A4B-it` (Gemma 4 MoE, 25.2B total / 3.8B active, 256K context, native tool calling as a first-class feature). AILANG is out-of-distribution for Gemma's pretraining and its Python/JS priors actively mislead freehand AILANG emission. This plan sidesteps that by removing AILANG-syntax authoring from the model's responsibilities.

**Related context:**
- `.agent/research/AILANG_performance_evidence_gates.md` — full research note; see the **"Structured Tool-Call Authoring — Deeper Analysis"** section for lever rationale, tool-surface inventory, granularity tradeoffs, dispatcher responsibilities, and interactions with other levers.
- `.agent/plans/Compose_Author_Premise_Tools.md` — read-side author-tool dispatcher that this plan extends with a write-side tool category.
- `.agent/plans/Compose_As_Extension.md` — extension host where the dispatcher lives.
- `.agent/summaries/2026-04-14-compose-author-premise-tools-plan-implementation.md` — current state of the author loop that this plan modifies.
- `.agent/summaries/2026-04-14-compose-regression-investigation-and-hardening.md` — parse-loop and type-loop hardening that this plan aims to make largely redundant for the parse class.
- `ailang-v0.9.0-docs.md` — authoritative AILANG language reference used to derive tool schemas.

---

## Goal

Replace free-text AILANG emission in the Compose author loop with a **structured tool-call authoring** surface (Option 2 — skeleton + free-text bodies). The model invokes tools like `set_module`, `add_import`, `define_func`, `build_block`, `build_match`; the dispatcher accumulates an in-memory program representation and renders canonical AILANG at `finalize()`. Function bodies and expression leaves remain free-text strings that the dispatcher parses on receipt, so parse errors inside bodies are caught at the tool level with structured feedback rather than after whole-snippet rendering.

**Primary success metric:** parse-error rate on finalized snippets drops toward zero on Gemma 4. Type-error rate is expected to stay roughly flat initially (grammars don't fix semantics) and becomes the next frontier.

## Motivation

Current behavior on Gemma 4 is dominated by parse/type loops — the model struggles to produce valid AILANG because AILANG is outside its pretraining distribution. Existing hardening (prompt compaction, parse-loop reset, type-loop reset, targeted-edit retry) helps the tail but does not address the root cause: the model is being asked to satisfy AILANG's syntax, type system, effect system, scope rules, and task semantics **simultaneously**, and breaks down on the first.

Structured tool-call authoring moves syntax and effect-row well-formedness into the dispatcher:
- The shape of valid AILANG becomes a dispatcher invariant.
- Gemma's native tool-calling strength is exercised instead of its weakest skill.
- Python/JS priors help (`add_import(...)` fits them) rather than hurt.
- Errors return as typed, localized, actionable tool-call results, not raw `ailang check` output.

Net: parse errors eliminated by construction; effect-row mismatches caught before `ailang check`; retry loops collapse into structured repair calls.

## Non-goals

- **Full-AST granularity (Option 1).** Out of scope for this plan. Revisit only if body-level parse errors dominate telemetry after Phase 4.
- **Grammar-constrained decoding.** Deferred (see research note) — requires endpoint control we do not have.
- **Fine-tuning on AILANG.** Explicitly out of scope; orthogonal and higher-cost.
- **Replacing the read-only author-tool dispatcher.** Those tools (`read_file`, `grep`, `list_dir`, etc. from `Compose_Author_Premise_Tools.md`) stay as-is. This plan adds a **write-side** tool category alongside.
- **Changing the fence-based fallback path.** For providers without native tool calling (OpenRouter pass-throughs, hosts that don't expose it), the current fence-parsed `tool_call` + `ailang` fence protocol remains the fallback.
- **Ledger / event-emission schema changes.** Same events (`compose_author_tool_call`, `compose_author_tool_result`, `compose_author_ledger_snapshot`) continue to carry the authoring tool calls.

## Assumptions (please confirm before Phase 0)

1. **Prerequisites landed.** `Compose_As_Extension` and `Compose_Author_Premise_Tools` are merged; `src/core/ext/compose/author_loop.ail` multi-turn loop is in place.
2. **Gemma 4 access path** — whichever hosted provider is used (Vertex AI, OpenRouter, Cloudflare Workers AI, or self-hosted vLLM) exposes native tool calling for Gemma 4. If not, this plan falls back to the existing fence path with no benefit. Verify before Phase 1.
3. **Capability flag.** A new provider-capability flag `supports_native_tool_calling` is plumbed through the runtime so the author loop can branch behavior.
4. **Schema source of truth.** Tool schemas for imports, builtins, and effects are derived from `ailang-v0.9.0-docs.md` and `ailang docs --list` output. A small regeneration script keeps them aligned with stdlib versions.
5. **Sandbox unchanged.** All authoring is in-memory until `finalize()`, which writes a rendered snippet through the same snippet-store path used today. No new FS surface.
6. **Budget default:** 40 authoring tool calls per snippet, configurable via `AILANG_COMPOSE_AUTHORING_BUDGET`. Separate from the read-tool budget (`AILANG_COMPOSE_AUTHOR_TOOLS_BUDGET`) because authoring calls dominate count.
7. **Default off** on first release (`AILANG_COMPOSE_STRUCTURED_AUTHORING=0`); flip default-on for Gemma-4 model strings in a follow-up after bake-in.
8. **Provider adapter layer.** Different providers emit tool calls in different shapes (OpenAI `tool_calls`, Anthropic `tool_use`, Gemini function calls, OpenRouter pass-through). A normalizing adapter lives in the runtime and presents a uniform internal representation.

---

## Protocol

Each author turn either:
1. Emits one or more **native tool calls** (provider API) against the authoring tool surface, or
2. Emits a final `finalize()` tool call, which triggers rendering + `ailang check`, or
3. (fallback path only) Emits a fenced `tool_call` JSON block in the existing Compose fence protocol.

The dispatcher:
- Validates each tool call against its JSON Schema at the provider boundary.
- Applies valid calls to the in-memory program state (atomic per call — failed calls do not mutate state).
- Returns a structured response; failures carry `error_class`, `detail`, and where possible `suggestion` / `did_you_mean`.
- Emits the same `compose_author_tool_call` / `compose_author_tool_result` ledger events as the read-side tools, with a `category: "authoring"` discriminator.

Termination:
- **Normal:** model calls `finalize()`, dispatcher renders + checks, returns `{ok: true, snippet: "..."}` or `{ok: false, errors: [...]}`. On `ok: true`, authoring ends.
- **Error on finalize:** returned errors are presented to the model which may call repair tools (surface E below) or mutators (`replace_func_body`, etc.) and retry `finalize()`.
- **Budget exhausted:** loop ends with `structured_authoring_budget_exhausted` event; falls back to free-text author path for the remaining attempts in this Compose invocation.

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
4. **Effect-row well-formedness** — effect names are from the fixed alphabet `{IO, FS, Net, Env, AI, Debug, Process, SharedMem, Stream}`. Declared row must be a superset of effects inferred from the body (walk the body AILANG fragment for known effectful calls).
5. **Scope checking (best-effort)** — free-text bodies are parsed; variables referenced but not bound in the accumulated block/function scope return `error_class: "unbound_identifier"`.
6. **Rendering** — canonical pretty-printer emits AILANG from internal state. Guarantees `{`/`;` vs `=`/`in` discipline and import ordering.
7. **`ailang check` at finalize** — the real parser/type-checker is authoritative. Any surviving parse error on finalize is a dispatcher bug; log it for investigation. Type errors are expected and returned to the model as structured errors (see Phase 3 repair tools).

---

## Phases

### Phase 0 — Inventory and schema draft (no code changes)
- **0.1** Inventory Gemma-4 failure modes on a recent Compose batch: run `scripts/analyze_compose_meta.py` against `.motoko-store/snippets` and classify failures (parse vs. type vs. runtime). Captures the baseline against which Phase 4 success will be measured.
- **0.2** Draft tool schemas as JSON Schema files under `src/core/ext/compose/authoring/schemas/`. One file per tool.
- **0.3** Verify native tool-call support on the target provider. Document the exact request/response shape and any per-provider quirks.
- **0.4** Agree on naming and surface scope with reviewers. Open a short decision log.

**Exit criteria:** baseline failure distribution captured; schemas drafted; provider tool-call shape confirmed.

### Phase 1 — Dispatcher and renderer (backend-only, no author-loop integration yet)
- **1.1** `src/core/ext/compose/authoring/state.ail` — internal program AST plus accumulator state.
- **1.2** `src/core/ext/compose/authoring/dispatcher.ail` — dispatches surface A tools, validates, mutates state.
- **1.3** `src/core/ext/compose/authoring/render.ail` — pretty-prints state → canonical AILANG source.
- **1.4** `src/core/ext/compose/authoring/stdlib_manifest.ail` — known imports and their symbols; generated from `ailang docs --list` output (script in `scripts/gen_stdlib_manifest.py`).
- **1.5** Round-trip test: for each snippet in a curated corpus (start with `.motoko-store/snippets` accepted attempts), parse into the internal AST (a separate importer — reuse `ailang check`'s AST emission if available, otherwise hand-roll for the subset we need), render, re-parse with `ailang check`. Round-trip should be idempotent on supported productions.
- **1.6** Error taxonomy: define `error_class` enum and expected response shapes.

**Exit criteria:** dispatcher passes schema validation on a suite of hand-written tool-call sequences; renderer round-trips against a curated corpus of ≥20 accepted snippets; unit tests green.

### Phase 2 — Author-loop integration behind capability flag
- **2.1** Add `supports_native_tool_calling` provider capability and thread through `src/tui/src/runtime-process.ts` and runtime `call` wrappers.
- **2.2** Add `AILANG_COMPOSE_STRUCTURED_AUTHORING` env flag.
- **2.3** `src/core/ext/compose/author_loop.ail` — new branch: when both `supports_native_tool_calling` and the flag are true, emit the authoring tool surface via native API; receive tool-call objects; dispatch through Phase 1 dispatcher; feed structured results back as tool-response messages.
- **2.4** Provider adapter layer in runtime: normalize OpenAI / Anthropic / Gemini / OpenRouter tool-call shapes into a uniform internal representation.
- **2.5** Ledger events `compose_author_tool_call` / `compose_author_tool_result` emit with `category: "authoring"` and `tool_name`; snippet-store sidecar includes the authoring trace.
- **2.6** Fallback path unchanged: when flag off or capability absent, existing free-text author path runs.
- **2.7** Event `structured_authoring_budget_exhausted` when the authoring budget is hit.

**Exit criteria:** with flag on and a Gemma-4 model configured, the author loop successfully produces at least one simple analyze snippet end-to-end via structured authoring; sidecar records the tool trace; fallback still works when flag is off.

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

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Gemma's tool-calling on the hosted endpoint is flaky or rate-limited | Verify in Phase 0.3; fallback path stays available; cap retries per call |
| Schema cognitive load on the model | Start with surface A only (~7 tools); add B/E progressively based on telemetry |
| Latency from turn count | Composite `scaffold_main` for the common case; keep bodies free-text under Option 2 |
| Free-text body still produces parse errors | Dispatcher parses and rejects at tool level with structured error; repair tools close the loop before `finalize()` |
| Dispatcher diverges from real AILANG parser | Round-trip corpus test (Phase 1.5) + real `ailang check` at finalize as authoritative check |
| Schema drift across AILANG versions | Schemas regenerated from `ailang docs --list`; per-release CI job |
| Model embeds raw AILANG inside string fields under pressure | Dispatcher parses long string fields and rejects unparseable ones |
| Telemetry volume from many small tool calls | Authoring events tagged `category: "authoring"` for filtering; single consolidated user-visible event per snippet |
| Provider tool-call shape differences | Adapter layer (Phase 2.4) normalizes to internal representation |
| Ledger / budget interaction with existing read-tool budget | Separate budget key (`AILANG_COMPOSE_AUTHORING_BUDGET`) |

---

## Open questions to resolve before or during Phase 0

1. AST handle representation — string IDs referenced across turns, or inline nested JSON composition? Probably both: inline for coarse tools, IDs for edits.
2. How much semantic validation in-dispatcher vs. deferred to `ailang check`? Current proposal: parse-level and scope-level in-dispatcher; type inference at finalize.
3. Composite template tool inventory — beyond `scaffold_main`, which other common shapes warrant first-class tools? Revisit after Phase 4 telemetry.
4. Provider-specific tool-call limits — does the target hosted path cap tool count, arg-schema complexity, or response size? Verify in Phase 0.3.
5. Fallback heuristic — if structured authoring attempts fail N times in a row on a given intent, should the loop fall back to free-text for the remainder of the Compose invocation? Propose yes, with `AILANG_COMPOSE_STRUCTURED_AUTHORING_FALLBACK_AFTER=3`.

---

## Relationship to the broader research note

This plan implements **lever 2** from `.agent/research/AILANG_performance_evidence_gates.md`. It is the highest-leverage lever that is fully deployable on currently-available hosted endpoints (lever 1, grammar-constrained decoding, is deferred pending endpoint control). The other levers in the research note (retrieval few-shot, error→hint table, conditional thinking mode, fine-tuning) remain candidates for follow-up plans; several are partially subsumed by the dispatcher's structured-error responses and may scope down as a result of this work.

See the research note for full rationale on why this lever fits Gemma 4 specifically, the granularity-tradeoff analysis behind choosing Option 2, and interactions with the other levers.
