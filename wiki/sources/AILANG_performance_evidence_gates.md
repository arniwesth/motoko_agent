# 2026-04-14 Note — Next Plan For AILANG Performance (Evidence Gates)

This note captures candidate changes for the **next** dedicated plan to improve Compose AILANG performance on analyze-style tasks.

## Problem Direction
Current behavior can still accept shallow or weakly grounded analysis, especially when `expected_output` is free text and validator confidence remains inconclusive.

## Proposed Next-Patch Ideas (for new plan)

1. Require minimum file evidence before success
- Add a hard success precondition for analyze intents:
  - at least `N` successful `readFile(...)` calls
  - files must be non-trivial (size/line-count threshold)
- Suggested env knobs:
  - `AILANG_COMPOSE_ANALYZE_MIN_READS` (default candidate: 2-4)
  - `AILANG_COMPOSE_ANALYZE_MIN_READ_BYTES` (default candidate: 200-500 per file)

2. Add grounded-findings retry gate
- Introduce a retry gate that marks attempt as `insufficient_output` when stdout lacks file-grounded findings.
- Gate should verify presence of:
  - concrete paths
  - extracted factual statements tied to those paths
- If missing, retry with explicit corrective hint: cite files read and concrete observed facts.

3. Prefer structured `expected_output` for Compose analyze calls
- Shift toward structured validators instead of free text:
  - `kind: "contains_all"` for required factual tokens/paths
  - `kind: "certificate"` when premise/trace/conclusion fidelity is required
- Treat unstructured/free-text `expected_output` as lower-confidence mode.

## Planning Note
A **new plan** should be created to design and implement these as a coherent "analyze evidence quality" phase, including:
- exact thresholds/defaults
- override env vars
- telemetry fields for gate failures
- test fixtures for pass/fail boundaries
- compatibility/ramp strategy to avoid over-rejecting legitimate concise outputs

## Target Model Implications (google/gemma-4-26B-A4B-it)

The agent is being developed to run on `google/gemma-4-26B-A4B-it` (Gemma 4 MoE, 25.2B total / 3.8B active, 256K context, Apache 2.0). Key capabilities to design against in the next plan:

- **Native function/tool calling**
  - Prefer using the provider's native tool-call API for `author_tools` instead of the current text-fence `tool_call` protocol when targeting Gemma 4.
  - Keep the fence parser as a fallback for providers without native tool calling, but treat native calling as the preferred path.
  - Impact on plan: the evidence gates (min reads, grounded findings) become easier to enforce because tool invocations are structured, not parsed from free text.

- **Native structured output**
  - Strongly favor structured `expected_output` validators over free text for analyze/summarize intents:
    - `kind: "contains_all"` for required paths/tokens
    - `kind: "certificate"` for premise/trace/conclusion fidelity
    - A new analyze-findings schema: required JSON object with `paths: [string]`, `facts: [{path, quote|summary}]`, `conclusion: string`
  - This aligns with idea (3) in the next-patch list and makes the grounded-findings gate straightforward.

- **256K context window**
  - Existing prompt compaction (`prompts.ail`) is still useful for cost/latency but is no longer load-bearing for correctness on this model.
  - Retry-context budgets can be relaxed where it improves repair quality, provided telemetry continues to show bounded growth.
  - Author-loop can safely carry richer ledger snapshots and prior-read summaries without truncation pressure.

- **Thinking / reasoning mode (`<|think|>`, `enable_thinking=True`)**
  - Multi-turn rule: thinking content from prior assistant turns must NOT be re-sent in subsequent turns — only the final answer belongs in history.
  - Author-loop transcript construction must strip any `<|channel>thought ... <channel|>` segments before replaying prior turns, otherwise output quality and token cost degrade.
  - Consider an opt-in toggle (e.g. `AILANG_COMPOSE_AUTHOR_THINKING`) to enable reasoning mode on hard analyze intents while defaulting off for simple runs.

- **Recommended sampling**
  - Standardized defaults are `temperature=1.0`, `top_p=0.95`, `top_k=64`. Revisit compose-side sampling overrides to match unless there is explicit reason to diverge.

- **Multimodal (text + image + video)**
  - Not used by Compose today. Out of scope for the evidence-gates plan, but worth recording as a future option (e.g. screenshot-grounded analyze intents).

- **Benchmarks worth knowing when calibrating gates**
  - LiveCodeBench v6: 77.1 — strong code generation; type/effect loops should be less frequent than on weaker models, so retry budgets can likely be tightened.
  - Long-context MRCR v2 @128k: 44.1 — long-context recall is mid; do not assume perfect recall of huge ledger snapshots. Keep the summarized prior-reads strategy in author prompts.

### Concrete items to fold into the new plan
1. Add a provider-capability flag (`native_tool_calling`, `native_structured_output`, `supports_thinking_mode`) and branch author-loop behavior on it.
2. When native tool calling is available, emit tool calls through the provider API; ledger/event emission stays identical.
3. Add a `thinking` transcript sanitizer in author-loop history construction.
4. Introduce a structured `analyze_findings` validator kind that maps directly onto the evidence gate (min reads, grounded facts, cited paths).
5. Update default sampling to Gemma 4 recommended values when model id matches `google/gemma-4*` (keep overrides for other providers).

## Gemma 4 AILANG-Code Validity — Problem Framing and Research Directions

### Observed problem
Gemma 4 26B A4B-it (the target model) struggles to produce valid AILANG source. Despite strong general code benchmarks (LiveCodeBench v6 77.1), AILANG is largely outside its pretraining distribution. This is fundamentally a **grounding/distribution-shift problem**, not a reasoning problem. Symptoms surface as recurrent parse failures and effect-row type errors even after the existing reset/retry hardening.

### Candidate levers (ordered by leverage vs. effort)

1. **Grammar-constrained decoding**
   - If the hosting path exposes it (vLLM + outlines/llguidance, or Vertex schema-constrained output wrapping code in JSON), constrain token sampling to a formal AILANG grammar (or at minimum a prefix grammar for critical structures: `module`, `import`, `func`, effect rows, block vs. expression `let`).
   - Kills invalid syntax at sampling time rather than retry time.
   - Highest ceiling when available; requires inference stack that supports it.

2. **Structured tool-call authoring instead of free-text code**
   - Replace "emit a complete .ail snippet" with a tool-call composition API:
     - `add_import(module, symbols)`
     - `define_func(name, params, return_type, effects, body_expr)`
     - `add_let(var, expr)`
     - `add_match(scrutinee, arms)`
     - `finalize()`
   - The *shape* of valid AILANG becomes the dispatcher's responsibility; the model only chooses content.
   - Plays to Gemma 4's native tool-calling strength; bypasses its weakest skill (freehand AILANG syntax).
   - Ledger/event emission stays unchanged; validator runs against the dispatcher-rendered source.

3. **Retrieval-conditioned few-shot exemplars**
   - Index `.motoko-store/snippets` (and curated seed exemplars) by intent-kind, required effects, and imports used.
   - On each author turn, retrieve top 1–3 known-good snippets and prepend them as exemplars — concrete, compiling examples beat abstract docs for an out-of-distribution model.
   - Needed regardless of other levers; cheap and high yield.

4. **Deterministic error → corrective-hint table**
   - Current retry resets are streak-based (after repeated failures). Add a deterministic map from specific `ailang check` error codes/markers to targeted hints, applied on the *first* occurrence:
     - `PAR_UNEXPECTED_TOKEN` near `in` inside `{}` → "replace `in` with `;` inside brace blocks"
     - `PAR_NO_PREFIX_PARSE` on `let (x,y) = ...` → "use `match tuple { (x, y) => ... }`"
     - `TYP_EFFECT_ROW_MISMATCH` missing `IO` → "add `IO` to the effect row of this function"
     - arity mismatch on `addC(3, 4)` → "curried lambda needs `addC(3)(4)`"
   - Cheap to build from the AILANG docs' "Common Mistakes" + "What AILANG Does NOT Have" sections.

5. **Thinking mode for hard intents only**
   - Enable `<|think|>` / `enable_thinking=True` for complex analyze/summarize or after N failed attempts; disable for trivial snippets to save tokens.
   - Strip thought channels from prior turns when replaying history (required by the provider).

6. **Skeleton-first, then hole-fill**
   - Generate a pinned skeleton from the intent (`module`, imports, `export func main() -> () ! {Effects} { … }`) deterministically, then ask the model only to fill the body expression. Reduces degrees of freedom where the model fails most.
   - Works well combined with (2) and (3).

7. **Fine-tuning / LoRA on a valid-AILANG corpus**
   - Highest ceiling, highest effort. Build a corpus from: stdlib examples, `ailang examples search`, accepted snippets from production runs, Z3-verified contract examples. Train a small LoRA adapter on Gemma 4.
   - Only worth investing in after (1)–(4) are exhausted, but it is the ultimate fix for distribution shift.

### Recommended starting point
Before investing in any lever, **quantify which errors dominate on Gemma 4 specifically**. Run `scripts/analyze_compose_meta.py` over a recent Gemma batch and categorize failures by:
- parse vs. type vs. runtime vs. guard
- specific error codes within each category
- whether the failure is syntactic (helped by grammars/tools) or semantic (helped by retrieval/hints)

Then attack the top class first. Prior expectation: **(2) structured tool-call authoring + (3) retrieval-conditioned few-shot** will move the needle most without infrastructure changes, and **(1) grammar-constrained decoding** is the unlock if the deployment path supports it.

### Items to add to the new plan
1. Measurement pass: per-error-class failure distribution on Gemma 4, captured as a baseline before any lever is applied.
2. Decision on hosting path: identify whether the production inference stack supports grammar-constrained or schema-constrained decoding for AILANG; if yes, elevate (1) to the primary lever.
3. Design sketch for the structured authoring tool-call API (names, parameter schemas, validation rules).
4. Retrieval index design: what metadata to store alongside each snippet, how to score similarity (intent-kind + effects + imports is likely enough).
5. Error→hint table as a data file (JSON/YAML) so it can be extended without code changes, with telemetry on which hints actually reduce next-attempt failure rate.
6. Exit criteria per lever: target validity rate improvement and cost/latency ceiling before declaring a lever "shipped."

## Why Frontier Models Handle AILANG Better Than Gemma 4 — And What That Implies

### The baseline question
AILANG is also outside the frontier-model pretraining distribution (e.g. Claude Opus 4.6 with a May 2025 cutoff does not have durable AILANG knowledge and effectively learns it in-context from `ailang-v0.9.0-docs.md` and repo files). Yet frontier models produce substantially more valid AILANG than Gemma 4 26B A4B-it. Understanding why is essential for picking the right levers, because it tells us which *capabilities* we need to substitute for when targeting the smaller model.

### Root causes of the capability gap

1. **Scale and in-context learning capacity.**
   - Frontier models have dramatically more capacity to absorb a multi-thousand-line spec and apply it consistently during generation.
   - Gemma 4 A4B activates 3.8B params per token. It can read the same docs but has less capacity to generalize correctly under generation pressure, especially for long snippets or unfamiliar constructs.

2. **Closeness of prior languages — the dominant factor.**
   - AILANG is built on Hindley-Milner, ADTs, algebraic effect rows, pattern matching, `let ... in` — territory shared with OCaml, Haskell, PureScript, F#, ReScript.
   - Frontier models have substantial exposure to those languages, so their nearest-neighbor guesses when writing AILANG are *close to correct*.
   - Gemma's pretraining mix is presumably heavier on Python/JS/Go. Those priors **actively mislead**: they pull generation toward `def`, `for`, `while`, `class`, `{...}` blocks with Python-style semantics, `list.map()` method syntax, etc. The AILANG docs' "What AILANG Does NOT Have" and "Common Mistakes" sections exist precisely to fight these reflexes — but a smaller model under load reverts to its priors.

3. **Constraint adherence under load.**
   - Frontier instruction-tuned models follow literal prohibitions ("do NOT write X; write Y instead") more reliably.
   - Smaller models degrade on constraint-following as context grows, task difficulty rises, or prior pressure increases. This explains parse-loop recurrence even after targeted hints.

4. **Error reasoning vs. error pattern-matching.**
   - Given a `TYP_EFFECT_ROW_MISMATCH`, a frontier model can reason about *where* the offending effectful call sits and *which* effect to add to the row.
   - A smaller model often pattern-matches the error string and produces a plausible-looking edit in the wrong location, causing retry churn even when a hint is provided.

5. **Possibly some training trickle-in.**
   - Frontier models trained through mid-2025 may have seen light exposure to AILANG / Sunholo packages / related GitHub content. Not enough to "know" the language, but enough to nudge priors.
   - Gemma 4's corpus composition is unknown to us; it may or may not have any exposure. Assume near-zero.

### Implications for the plan

The practical conclusion: the gap between frontier and Gemma on AILANG is mostly (2) — closer priors — amplified by (1) better in-context learning. The research levers proposed above map cleanly onto this diagnosis:

- **Retrieval-conditioned few-shot (lever 3)** substitutes for "closer priors." If Gemma cannot derive correct AILANG from Haskell-like priors, give it *actual correct AILANG* for the current intent shape as an in-context exemplar. This directly replaces the mechanism frontier models use implicitly.

- **Structured tool-call authoring (lever 2)** substitutes for "better in-context learning under constraint pressure." If Gemma cannot reliably hold the full grammar in mind while generating, have the dispatcher enforce grammar and only ask the model to fill content slots. This converts a syntax-correctness problem into a content-choice problem, which Gemma handles well.

- **Grammar-constrained decoding (lever 1)** is the hardest enforcement of the same principle: even content choice is constrained at the token level. Highest ceiling; requires infrastructure support.

- **Error→hint table (lever 4)** substitutes for "error reasoning." When the model cannot derive the correct fix from the error text, precompute the mapping deterministically.

- **Fine-tuning / LoRA (lever 7)** is the **only** lever that actually moves the priors themselves. Everything else is a workaround. That is why it has the highest ceiling but also the highest cost, and why it should be reserved for the case where workarounds plateau below the required validity rate.

### Added design principle
When selecting and ordering levers, prefer those that **substitute for priors** (retrieval, exemplars, constrained decoding) before those that **patch specific failures** (error→hint tables), and reserve **prior-shaping** (fine-tuning) for last. This ordering reflects generality: prior-substitution levers help with every unfamiliar construct; hint tables only help with observed ones.

## Grammar-Constrained Decoding — Deeper Analysis

> **Status: DEFERRED TO FUTURE RESEARCH.** We do not currently control the inference endpoint for `google/gemma-4-26B-A4B-it` (access is via hosted providers: OpenRouter, Vertex AI, Cloudflare Workers AI, etc.), and real grammar-constrained decoding requires either self-hosting on vLLM (or similar) or a provider that exposes CFG-level constraints, which today none of our available endpoints do. The most we can use under the current hosting is JSON-schema-wrapped output (Vertex / Gemini API / OpenAI-style structured outputs). This section documents the full analysis so the plan is ready to be activated if/when we gain endpoint control (e.g. self-hosted vLLM deployment, or a provider that exposes xgrammar/llguidance/outlines).

### What it actually is, mechanically
At each decoding step the model emits logits over the full vocabulary (~260K tokens for Gemma 4). A parser tracking the grammar's current state computes the set of tokens that could *continue a legal parse*, and all other tokens have their logits set to `-inf` before sampling. The model physically cannot emit invalid syntax; it is not "generate then check," it is "the set of generatable continuations equals the set of legal continuations." Parse errors are eliminated by construction, not by retry.

The hard part is aligning a grammar written over *terminal symbols* (keywords, punctuation, identifiers) with the model's *BPE tokens*, which do not respect those boundaries. Modern libraries (xgrammar, llguidance) solve this efficiently by precomputing, for each grammar state, a bitmask over the vocabulary. Per-token overhead is tens of microseconds at the high end — effectively free compared to the forward pass.

### Implementation ecosystem and where Gemma can use each

| Library | Expressiveness | Host integrations | Notes |
|---|---|---|---|
| **xgrammar** (MLC) | Full CFG (EBNF) | vLLM, SGLang, MLC-LLM | Fastest current option; minimal overhead; strong CFG support |
| **llguidance** (Microsoft) | CFG + lexer + interleaving | vLLM plugin, Guidance | Strong on mixed free-text/structured regions (e.g. thinking + constrained answer) |
| **Outlines** | Regex, JSON schema, Lark CFG | vLLM, TGI, transformers | Most mature Python ergonomics; Lark grammars are easy to author |
| **llama.cpp GBNF** | CFG | llama.cpp, LM Studio | Useful for local/quantized Gemma; GBNF is verbose but works |
| **Vertex AI / Gemini API** | JSON schema only | Hosted | No CFG; only structured-JSON output |
| **OpenAI structured outputs** | JSON schema only | Hosted | No CFG |
| **OpenRouter** | Whatever the provider exposes | Pass-through | Not a constraint point itself |
| **Anthropic API** | None at decode time | — | No exposed constrained decoding |

For Gemma specifically, the realistic path to true CFG constraints is **self-hosted vLLM + xgrammar or llguidance**, because that is where you control both the model and the decoder. Hosted Gemma (Vertex, Cloudflare Workers AI) gives you JSON schema only — real but weaker. OpenRouter inherits whatever the upstream provider supports.

### Three grammar strategies, in increasing strength

**1. JSON-schema-wrapped code.** Model emits `{"module": "...", "imports": [...], "body": "..."}` under schema enforcement. Outer shape guaranteed; body still free text. Deployable *today* on Vertex/Gemini/OpenAI. Catches missing module declarations, malformed imports, omitted effect rows — but body parse errors are untouched. Weakest strategy, lowest infrastructure cost. Good first step and **the only strategy available without endpoint control.**

**2. Prefix / skeleton CFG.** A partial AILANG grammar covering only the high-risk, high-failure-rate productions:
- top-level structure: `module path/name`, `import` forms, `export? pure? func name(...) -> T ! {...}`
- effect rows: fixed alphabet `{IO, FS, Net, Env, AI, Debug, Process, SharedMem, Stream}`
- block-vs-expression `let` discipline — after `{` require `;`, after `=` require `in`
- match arm syntax — `pattern => expr` with comma separation, brace-wrapping when arm has multiple lets
- call-style — `f(a, b)` multi-arg grammar distinct from curried-lambda definitions

Expression bodies remain free. This catches roughly the "Common Mistakes" table in the docs by construction. Much easier to author and maintain than a full grammar. The right *default* strategy once CFG decoding becomes available.

**3. Full AILANG CFG.** Every production constrained, mirroring the real parser. Highest validity guarantee, but requires:
- authoring the full grammar in Lark/EBNF/GBNF
- keeping it in lockstep with AILANG releases (v0.8.2 → v0.9.0 added `selectEvents`, `spawnProcess`, etc.)
- a test corpus that exercises every production the real parser accepts

Worth it only once (2) plateaus.

### What grammar constraints *do not* solve

Grammars are context-free; AILANG is not. The following failures survive any grammar:
- **Type errors** — `TYP_MISMATCH`, arity mismatches on already-defined multi-arg functions, record field errors
- **Effect-row mismatches** — grammar can force *some* effect row to appear, but not the *right* one for the calls in the body
- **Undefined identifiers** — grammar allows any identifier in scope-agnostic positions
- **Hindley-Milner inference failures** — e.g. ambiguous `foldl` callback typing
- **Semantic correctness** — does the code solve the task

Expected empirical picture after deploying grammar constraints: parse-error class drops toward zero; type-error class stays roughly where it was and may rise proportionally as a share of remaining failures. That is fine — it narrows the problem. The error→hint table and the type-loop reset logic already in place are the right tools for the remaining class.

### Interaction with the other research levers

- **vs. structured tool-call authoring (lever 2)** — these converge at the limit. A fully constrained grammar *is* a tool-call API expressed at token level during decode. Practical difference: grammars need no protocol changes and keep one round-trip per snippet; tool-call APIs require multi-turn orchestration but give the dispatcher richer semantic control (type checks, scope validation per call). A sound design is **skeleton grammar + tool-call API for body composition** — grammar guarantees the file shape; tool calls guarantee the body is composed from known-valid fragments.
- **vs. retrieval few-shot (lever 3)** — complementary. Grammar guarantees validity *if* the model assigns non-trivial probability to any valid continuation. Retrieval raises that probability mass. Without retrieval, a constrained model under bad priors can produce syntactically-valid-but-absurd code.
- **vs. error→hint table (lever 4)** — grammar makes most parse-error hints redundant; type-error hints remain valuable. Scope of the hint table can shrink to type/effect errors only.
- **vs. thinking mode (lever 5)** — llguidance handles interleaved free-text-then-constrained regions natively. The model can think freely inside `<|think|>` and be grammar-constrained only after the thought channel closes. xgrammar and outlines can do this with a conditional grammar.
- **vs. fine-tuning (lever 7)** — orthogonal. A fine-tuned model + grammar is the strongest combination: tuning shifts prior mass toward valid AILANG, grammar guarantees it.

### Costs, risks, ongoing work

1. **Grammar drift.** If the AILANG parser accepts something the grammar rejects, the constraint silently prevents the model from emitting valid programs. Detection mechanism: run the grammar against every accepted snippet in `.motoko-store/snippets` as a regression suite. A snippet that `ailang check` accepts but the grammar rejects is a grammar bug.
2. **Over-restriction pathologies.** If the model's probability mass is concentrated on tokens the grammar rejects, constrained sampling can force a low-probability path, producing legal-but-weird code ("path of least remaining resistance"). Mitigation: combine with retrieval so the model has high-probability valid choices available.
3. **Inference overhead.** Modern libraries: <5% latency overhead. Older or naïve implementations: 2–10x slower. Use xgrammar or llguidance, not a from-scratch mask.
4. **Maintenance burden.** Each AILANG release potentially changes the grammar. Ties the project to whatever cadence the language evolves.
5. **Debuggability loss.** When the model "wants" to produce something invalid and is constrained away, the surviving output can be confusing. Good telemetry: log when a constraint mask zeroed out >95% of the distribution — a signal the model was about to go off the rails and the resulting output may be low-quality.

### Recommended staged path (for when endpoint control becomes available)

1. **Start with JSON-schema wrapping** in whatever hosted path is in use. Zero infrastructure, captures top-level structure. Measure impact on parse-error rate. *This is the only step available under current hosting and should be explored anyway as part of the evidence-gates plan's structured-output work.*
2. **Build a skeleton CFG** in Lark (easiest authoring) covering the productions from the "Common Mistakes" table. Validate against the accepted-snippet corpus.
3. **Decide hosting.** If deployment stays on hosted Gemma (Vertex), we are stuck with JSON schema. If self-hosted vLLM becomes viable, that unlocks xgrammar/llguidance CFG.
4. **Integrate the skeleton grammar** behind a provider-capability flag (`supports_cfg_decoding`). Compose falls back to the current free-text path otherwise.
5. **Measure again.** Expect parse errors to collapse; type errors to stay. Extend the grammar where residual syntactic failures remain.
6. **Expand toward full CFG** only once the skeleton plateaus and a residual syntactic failure class justifies the maintenance cost.

### Open items to verify when this research is reactivated

- Current state of xgrammar's CFG support for grammars with AILANG's complexity (effect rows + Hindley-Milner type syntax can stress the automaton compilation step).
- Whether a production hosting path will allow vLLM self-hosting of Gemma 4 at acceptable cost/latency, or whether we remain committed to hosted-only (which caps us at JSON schema).
- Whether llguidance's interleaved free-text/constrained mode is stable enough for thinking-then-answer flows on Gemma 4 specifically.
- Licensing / redistribution of the AILANG grammar if shipped as part of the agent package.

### Deferral rationale (explicit)
Grammar-constrained decoding is the single highest-leverage lever for AILANG validity on a non-native model, but it requires **endpoint-level control** that is not currently available to this project. Until the team controls a vLLM/SGLang/MLC deployment (or a hosted provider exposes CFG-level constraints), the applicable subset is narrow: JSON-schema wrapping is usable today, and all CFG work is deferred. The analysis above should be treated as the activation checklist for when endpoint control is acquired, and the other levers (retrieval few-shot, structured tool-call authoring, error→hint table, conditional thinking mode) should carry the weight in the interim.

## Structured Tool-Call Authoring — Deeper Analysis

> **Status: PRIMARY NEAR-TERM CANDIDATE.** This lever is fully deployable on currently-available hosted endpoints (Vertex AI Gemma, OpenRouter pass-through, OpenAI-compatible providers, Anthropic, self-hosted) because it depends only on **native tool calling**, which Gemma 4 supports as a first-class feature. It does not require endpoint-level control and does not require waiting on infrastructure changes.

### The core shift in responsibility

The current flow asks the model for a string: "emit a valid `.ail` file that solves this intent." That string must simultaneously satisfy AILANG's syntax, type system, effect system, scope rules, and the task. Gemma 4 breaks down on the first of those — *syntax* — so everything downstream falls over even when the task was understood correctly.

Structured tool-call authoring inverts the contract: the model never types source code. It invokes tools like `set_module`, `add_import`, `define_func`, `build_block`, `build_match` — each with a narrow, typed schema. The dispatcher accumulates calls into an in-memory program representation and renders it to AILANG only at `finalize()`. **The shape of valid AILANG becomes the dispatcher's invariant, not the model's problem.**

This is the same principle as grammar-constrained decoding but operating at action granularity instead of token granularity. The critical difference: **it requires no endpoint control.** It is a viable primary lever today while CFG is deferred.

### Why it plays to Gemma 4 specifically

1. **Native tool calling is a first-class feature** on Gemma 4, per the HF model card. Google invested in it during instruction tuning — structured tool invocation is a mode the model was shaped to do well.
2. **Per-call schemas are narrow.** The model does not need to hold the full AILANG grammar in mind — only the schema of the current tool, typically ~5 fields of well-known JSON.
3. **Python/JS priors help rather than hurt.** When authoring `add_import("std/fs", ["readFile"])`, Gemma's Python/JS priors produce exactly the right shape. Those same priors were *misleading* when it was asked to write AILANG directly.
4. **Errors come back as structured tool errors**, not as opaque parser output. The model can reason over `{error: "unknown_symbol", detail: "std/list does not export 'foo'", suggestions: ["foldl", "foldr"]}` far more reliably than over `PAR_NO_PREFIX_PARSE at line 7 col 23`.

### Tool surface — what to expose

Categorized from coarse to fine:

**A. Program skeleton**
- `set_module(path: string)`
- `add_import(module: string, symbols: [string], alias: string | null)`
- `add_type_alias(name, type_params, definition)` — for `type` declarations
- `define_type(name, type_params, constructors: [{name, fields}], derives: [string])` — ADTs
- `define_func(name, params, return_type, effects, body_ref, is_pure, is_export)`
- `set_main(body_ref, effects)` — pins the entry function
- `finalize()` — render, run `ailang check`, return result

**B. Block and expression construction**
- `build_block(id, statements: [StatementNode])` — the `{ ... ; ... ; ... }` shape
- `build_let(var, expr_ref, in_ref | null)` — expression-style vs block-style resolved by context
- `build_if(cond_ref, then_ref, else_ref)`
- `build_match(scrutinee_ref, arms: [{pattern, expr_ref}])`
- `build_call(fn, args: [expr_ref])`
- `build_lambda(params, body_ref, recursive: bool)` — handles `\x. ...` and `letrec`
- `build_record(fields: [{name, value_ref}])`
- `build_record_update(base_ref, updates: [{name, value_ref}])`
- `build_literal(kind: "int" | "float" | "string" | "bool", value)`
- `build_list(elements: [expr_ref])`
- `build_binop(op, left_ref, right_ref)`
- `build_var(name)`

**C. Pattern construction**
- `build_pattern_literal(value)`
- `build_pattern_constructor(name, args: [pattern_ref])`
- `build_pattern_cons(head_ref, tail_ref)`
- `build_pattern_record(fields: [{name, binding | nested}], rest: bool)`
- `build_pattern_wildcard()`
- `build_pattern_var(name)`

**D. Type construction** (for signatures and annotations)
- `build_type_atomic(name)` — `int`, `bool`, `string`
- `build_type_list(element_ref)`
- `build_type_record(fields: [{name, type_ref}], open: bool)`
- `build_type_func(params: [type_ref], return_ref, effects: [string])`
- `build_type_adt(name, params: [type_ref])` — `Option[int]`, `Result[string]`

**E. Repair / edit tools** — for retry mode
- `replace_func_body(func_ref, new_body_ref)`
- `add_effect_to_func(func_ref, effect)`
- `change_call_style(expr_ref, style: "multi_arg" | "curried")`
- `wrap_in_block(expr_ref)`

### Granularity tradeoff — the key design decision

**Option 1 — "Full AST" (highest granularity).** Every AILANG node is a tool call. Model literally never types source code. Parse errors are impossible by construction. Cost: 20–50 tool calls per snippet, heavy schema cognitive load, slow, expensive.

**Option 2 — "Skeleton + free-text bodies" (medium).** Module, imports, function signatures, effect rows, match structure, ADT declarations are all tool calls. Function bodies and expression leaves are free-text strings that the dispatcher parses on receipt. Parse errors inside bodies are possible but caught at the tool level with structured feedback, not after full snippet rendering.

**Option 3 — "Signatures only + free-text code" (coarsest).** `define_func(name, signature, body)` where signature is structured (parsed by dispatcher) and body is free-text AILANG. Only the parts Gemma reliably gets wrong (module header, effect rows, imports) are structured; the rest is legacy free text.

For Gemma 4, the right starting point is **Option 2**. Rationale:
- Failures driving retry loops are structural (effect rows, block/expression `let`, import syntax, match-arm braces), not expression-level. Option 2 fixes those.
- Bodies are short enough and expression-level AILANG is close enough to OCaml/Haskell that even Gemma gets leaf-level expressions right most of the time once the frame is pinned.
- Option 1 is a large up-front investment with diminishing returns if the residual failure class is type errors rather than parse errors.
- Option 2 degrades gracefully: if body parse errors dominate telemetry after deployment, individual expression builders (from surface B) can be added incrementally.

### Dispatcher responsibilities

The tool-call dispatcher does more than accumulate — it is the semantic validator:

1. **Schema validation** — reject malformed tool calls at the provider level using JSON Schema.
2. **Reference integrity** — `build_block(statements: [...])` referring to expr ids that were never created → structured error.
3. **Import / symbol validation** — `add_import("std/fs", ["read"])` where `read` is not exported → structured error with `did_you_mean`.
4. **Effect-row well-formedness** — effects must be from the known alphabet; the declared row must be a superset of the effects inferred from the body (the dispatcher can walk the body and compute required effects, catching mismatches *before* `ailang check`).
5. **Scope checking** — `build_var("content")` inside a block that does not bind `content` → structured error.
6. **Arity checking** — `build_call("println", [a, b])` when `println` takes one arg → structured error.
7. **Rendering** — canonical pretty-printer from internal AST → AILANG source. This is where `{`/`;` vs `=`/`in` discipline is enforced automatically.
8. **Final `ailang check`** — run the real parser/type-checker on the rendered source. Any surviving error is a dispatcher bug (by construction it should not happen for parse errors; type errors may still occur if the dispatcher's light type checking missed something).

### Error feedback — the quiet multiplier

Today, when retry happens, the model sees raw parser output (often truncated and deduplicated by the prompt-compaction pipeline). Under structured authoring, every failed tool call returns a **typed, localized, actionable error**:

```json
{
  "ok": false,
  "error_class": "effect_row_insufficient",
  "tool": "define_func",
  "arg": "effects",
  "detail": "body uses readFile (FS), println (IO), but effects = [IO]",
  "suggestion": "effects should be [\"IO\", \"FS\"]"
}
```

The model can repair without understanding the full error-message format. This subsumes most of what the error→hint table (lever 4) would need to cover — dispatcher errors *are* hints, generated per call from structured context the dispatcher already has.

### Relationship to existing infrastructure

The current `src/core/ext/compose/author_tools.ail` is a **read-only** tool dispatcher (`list_files`, `read_file`, `grep`, etc. — used by the author loop to gather context). Structured authoring tools are a **new, write-side** category on top of the same dispatcher pattern:

- Tool-call parsing, malformed handling, per-call telemetry — **reuse** from author_tools
- Ledger event emission (`compose_author_tool_call`, `compose_author_tool_result`) — **reuse**
- Budget accounting — **reuse**, but authoring calls may need a separate budget pool since they will dominate call count
- Fence fallback for providers without native tool calling — **reuse** the existing fence parser

The new pieces:
- Schema definitions for authoring tools
- In-memory program state machine
- AILANG pretty-printer
- Structured error taxonomy

### Implementation path

**Phase 1 — Schemas and dispatcher skeleton.** Define tool schemas as JSON. Build the dispatcher state machine (accumulate, validate, render). Write a pretty-printer that emits canonical AILANG from the internal AST. Test against a corpus of known-good snippets: round-tripping accepted snippets (parse → internal AST → render → re-parse) should be idempotent.

**Phase 2 — Author-loop integration behind capability flag.** New flags `supports_native_tool_calling` and `AILANG_COMPOSE_STRUCTURED_AUTHORING`. When both true, author loop emits the structured tool surface via the provider's native tool-calling API. When false, falls back to existing free-text path. Ledger emission stays identical.

**Phase 3 — Error taxonomy and repair tools.** Surface E (repair tools) is added once telemetry shows which errors recur. Each repair tool targets a specific dispatcher error class.

**Phase 4 — Measurement.** Primary metrics: parse-error rate on finalized snippets (target: near zero), type-error rate (expected: ~flat initially), tool calls per successful snippet (budget target), failed tool calls per snippet (repair efficiency), first-attempt success rate (the big number).

**Phase 5 — Expansion.** If body parse errors dominate, add finer expression builders (Option 2 → Option 1 selectively). If semantic errors dominate, push more checking into the dispatcher.

### Costs and risks

1. **Schema cognitive load on the model.** A 20-tool surface can overwhelm smaller models. Mitigation: group tools by phase (skeleton tools available first, expression tools exposed only after skeleton is pinned). Some providers allow progressive tool exposure; Gemma's support here should be verified.
2. **Latency from turn count.** 5–10 tool calls per snippet vs. 1 generation. Mitigation: composite tools for common shapes (`scaffold_main(effects, body)` for the common case) and keep leaf-level free text under Option 2.
3. **Expressiveness ceiling.** Some AILANG constructs (complex higher-kinded types, contracts, `deriving` edge cases) are awkward to express as tool calls. Mitigation: free-text escape hatches for rare constructs, accepting those will hit parse-error paths occasionally.
4. **Ledger / telemetry volume.** Authoring sessions will emit many tool-call events. Mitigation: consolidate into a single user-visible "authored program" event; keep raw sequence in a separate telemetry stream.
5. **Schema evolution with AILANG versions.** New syntax (e.g. v0.9.0's `spawnProcess`, `selectEvents`) requires schema updates. Mitigation: schemas derived from the AILANG stdlib docs and regenerated per release; additive changes dominate, so breakage should be rare.
6. **Model regression to free text.** Under pressure, Gemma may try to embed actual AILANG source inside a string field. Mitigation: dispatcher treats suspiciously-long string fields as a parse target and either validates or rejects.
7. **Provider tool-call-shape differences.** OpenAI-style `tool_calls` array, Anthropic-style `tool_use` blocks, Gemini-style function calls, OpenRouter pass-through variations. Mitigation: an adapter layer that normalizes all providers to the same internal tool-call representation — a small lift but real.

### Interaction with the other levers

- **vs. grammar-constrained decoding (lever 1):** converges at the limit; tool-call authoring is the action-granularity version that is deployable today without endpoint control. If CFG becomes available later, the two can compose — tool calls for structure, CFG for the free-text body slots.
- **vs. retrieval few-shot (lever 3):** the exemplars change from *source-code snippets* to *tool-call sequences*. Index successful authoring traces and prepend the closest match to the new intent. This is a different retrieval index from today's snippet store (`.motoko-store/snippets`) and needs its own design.
- **vs. error→hint table (lever 4):** mostly subsumed — dispatcher errors are structured hints by design. The hint table reduces to a small residual for errors that cross the dispatcher boundary (rare type errors caught only by `ailang check` at finalize).
- **vs. thinking mode (lever 5):** compatible. Provider tool-calling APIs generally allow the model to emit thought content before tool calls. The transcript-sanitation rule still applies — strip thought channels from prior turns.
- **vs. fine-tuning (lever 7):** highly complementary. If fine-tuning is pursued later, train on tool-call sequences rather than raw `.ail` text. Signal-to-noise per training token is much higher because every token is semantically meaningful (no whitespace, no `{`, no `;`). This also future-proofs the fine-tuning investment: tool schemas are more stable than language syntax.

### Design questions to resolve before implementation

1. **AST handle representation** — string IDs (`"b1"`, `"b2"`) referenced across tool calls, or nested inline JSON composition within a single tool call? String IDs give finer granularity; inline composition gives fewer turns. Probably support both: coarse tools (`build_block`) take inline structures; finer edits use IDs.
2. **How much semantic validation inside the dispatcher vs. deferred to `ailang check`?** More in-dispatcher checking → faster feedback, more dispatcher maintenance. Draw the line at: parse-level and scope-level in-dispatcher; type inference in `ailang check`.
3. **Composite / template tools** — should common program shapes (`scaffold_analyze_main(reads, findings)`) be first-class tools? Yes, probably, for the intents Compose sees most often. These collapse 5 tool calls into 1 for the 80% case.
4. **Rollback semantics on failed tool calls** — does a failed call leave the program state untouched, or is it tentatively applied and marked? Probably untouched (atomic per call), so the model can retry or take a different path cleanly.
5. **Budget accounting** — separate budget for authoring tool calls from existing read-only tool calls? Almost certainly yes, since call counts and cost profiles differ.

### Why this should be the primary near-term investment

With CFG deferred for endpoint reasons, structured tool-call authoring is the highest-leverage lever **fully deployable today**. It directly attacks Gemma's weakest skill (AILANG syntax) by removing it from the model's responsibilities, while playing to its tested-strong skill (native tool calling). The implementation is additive — existing free-text path stays as a fallback — so deployment risk is bounded. The measurement story is clean: parse-error rate on finalized snippets is a single, direct, interpretable success metric.

